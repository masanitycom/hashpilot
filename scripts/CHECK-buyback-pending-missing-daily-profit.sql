-- ============================================================
-- 買取申請中ユーザーの日利取りこぼし（全件集計）
--
-- 事象:
--   process_daily_yield_v2 は buyback_requests に status='pending' が
--   存在するだけでユーザーを除外する。日付を見ていない。
--   日利は「その日の分を翌日に入力」するため、申請が入力より先に届くと
--   申請日以前の日利まで配布されない。
--
-- 仕様（docs/TODO.md 2026-02-07確定）: 買取申請の翌日から日利停止
--   → 配布対象は「日利の日付 <= 申請日(JST)」まで
--
-- 実行日: 2026-09-05
-- ============================================================


-- ------------------------------------------------------------
-- 【1】ユーザー別・日別の未配布明細
--   1枚あたり = distribution_dividend / total_nft_count（関数と同じ計算）
-- ------------------------------------------------------------
WITH pending_req AS (
  SELECT DISTINCT ON (br.user_id)
    br.user_id,
    (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日
  FROM buyback_requests br
  WHERE br.status = 'pending'
  ORDER BY br.user_id, br.request_date ASC   -- 同一ユーザーに複数あれば最も古い申請を採用
),
missing AS (
  SELECT
    pr.user_id,
    pr.申請日,
    dyl.date,
    (dyl.distribution_dividend / NULLIF(dyl.total_nft_count, 0)) AS 一枚あたり,
    (SELECT COUNT(*) FROM nft_master nm
      WHERE nm.user_id = pr.user_id
        AND nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= dyl.date)                 AS 対象枚数
  FROM pending_req pr
  JOIN users u ON u.user_id = pr.user_id
  JOIN daily_yield_log_v2 dyl
    ON dyl.date <= pr.申請日
   AND dyl.date >  pr.申請日 - INTERVAL '15 days'   -- 申請直前の取りこぼしのみ対象
  WHERE u.has_approved_nft = true
    AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
    AND NOT EXISTS (
      SELECT 1 FROM nft_daily_profit ndp
      WHERE ndp.user_id = pr.user_id AND ndp.date = dyl.date
    )
)
SELECT
  user_id, 申請日, date AS 未配布日, 対象枚数,
  ROUND(一枚あたり::numeric, 4)                AS 一枚あたり,
  ROUND((一枚あたり * 対象枚数)::numeric, 3)   AS 不足額
FROM missing
WHERE 対象枚数 > 0
ORDER BY user_id, date;


-- ------------------------------------------------------------
-- 【2】ユーザー別サマリ
-- ------------------------------------------------------------
WITH pending_req AS (
  SELECT DISTINCT ON (br.user_id)
    br.user_id, (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日
  FROM buyback_requests br WHERE br.status = 'pending'
  ORDER BY br.user_id, br.request_date ASC
),
missing AS (
  SELECT
    pr.user_id, pr.申請日, dyl.date,
    (dyl.distribution_dividend / NULLIF(dyl.total_nft_count, 0)) AS 一枚あたり,
    (SELECT COUNT(*) FROM nft_master nm
      WHERE nm.user_id = pr.user_id AND nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= dyl.date)                 AS 対象枚数
  FROM pending_req pr
  JOIN users u ON u.user_id = pr.user_id
  JOIN daily_yield_log_v2 dyl
    ON dyl.date <= pr.申請日 AND dyl.date > pr.申請日 - INTERVAL '15 days'
  WHERE u.has_approved_nft = true
    AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
    AND NOT EXISTS (
      SELECT 1 FROM nft_daily_profit ndp
      WHERE ndp.user_id = pr.user_id AND ndp.date = dyl.date
    )
)
SELECT
  user_id, 申請日,
  COUNT(*)                                    AS 未配布日数,
  MIN(date)                                   AS 開始,
  MAX(date)                                   AS 終了,
  MAX(対象枚数)                                AS 枚数,
  ROUND(SUM(一枚あたり * 対象枚数)::numeric, 3) AS 不足額
FROM missing
WHERE 対象枚数 > 0
GROUP BY user_id, 申請日
ORDER BY SUM(一枚あたり * 対象枚数) DESC;


-- ------------------------------------------------------------
-- 【3】全体の総額（補填の規模）
-- ------------------------------------------------------------
WITH pending_req AS (
  SELECT DISTINCT ON (br.user_id)
    br.user_id, (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日
  FROM buyback_requests br WHERE br.status = 'pending'
  ORDER BY br.user_id, br.request_date ASC
),
missing AS (
  SELECT
    pr.user_id, dyl.date,
    (dyl.distribution_dividend / NULLIF(dyl.total_nft_count, 0)) AS 一枚あたり,
    (SELECT COUNT(*) FROM nft_master nm
      WHERE nm.user_id = pr.user_id AND nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= dyl.date)                 AS 対象枚数
  FROM pending_req pr
  JOIN users u ON u.user_id = pr.user_id
  JOIN daily_yield_log_v2 dyl
    ON dyl.date <= pr.申請日 AND dyl.date > pr.申請日 - INTERVAL '15 days'
  WHERE u.has_approved_nft = true
    AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
    AND NOT EXISTS (
      SELECT 1 FROM nft_daily_profit ndp
      WHERE ndp.user_id = pr.user_id AND ndp.date = dyl.date
    )
)
SELECT
  COUNT(DISTINCT user_id)                     AS 対象人数,
  COUNT(*)                                    AS 未配布レコード数,
  ROUND(SUM(一枚あたり * 対象枚数)::numeric, 2) AS 補填総額
FROM missing
WHERE 対象枚数 > 0;


-- ------------------------------------------------------------
-- 【4】買取申請が重複しているユーザー
--   59D41C に2件の pending が確認されている
-- ------------------------------------------------------------
SELECT user_id, COUNT(*) AS pending件数,
       MIN(request_date) AS 最古, MAX(request_date) AS 最新,
       SUM(total_buyback_amount) AS 合計申請額
FROM buyback_requests
WHERE status = 'pending'
GROUP BY user_id
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 【5】長期間 pending のまま放置されている申請
--   CE4129 は 2026-06-09 申請でまだ pending（3か月近く）
-- ------------------------------------------------------------
SELECT
  user_id,
  (request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日,
  (CURRENT_DATE - (request_date AT TIME ZONE 'Asia/Tokyo')::date) AS 経過日数,
  total_nft_count AS 枚数,
  total_buyback_amount AS 申請額,
  transaction_id
FROM buyback_requests
WHERE status = 'pending'
ORDER BY request_date;
