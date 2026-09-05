-- ============================================================
-- 買取申請ユーザーの日利取りこぼし補填
--
-- 事象:
--   process_daily_yield_v2 が buyback_requests の status='pending' を
--   日付を見ずに判定していたため、日利の入力が申請より後になった日は
--   申請日以前の分まで配布されなかった。
--
-- 仕様（docs/TODO.md 2026-02-07確定）: 買取申請の翌日から日利停止
--   → 「日利の日付 <= 申請日(JST)」までは配布されるべき
--
-- 対象: 46名 / 92(ユーザー×日) / 合計 $92.77
--   ※ nft_daily_profit はNFT1枚に1行入るため、実際の挿入行数はこれより多い
--
-- 1枚あたり = distribution_dividend / total_nft_count（関数と同じ計算）
--
-- ⚠️ 補填分はその日の配当原資に含まれていなかった金額。
--    除外された人を除いて山分けした後なので、原資を少し超えて支払う形になる。
--
-- 実行日: 2026-09-05
-- ============================================================


-- ============================================================
-- STEP 1: 補填対象を作業テーブルに確定させる
--   （この時点ではまだ何も書き込まれない）
-- ============================================================
DROP TABLE IF EXISTS backfill_buyback_20260905;

CREATE TABLE backfill_buyback_20260905 AS
WITH pending_req AS (
  SELECT DISTINCT ON (br.user_id)
    br.user_id,
    (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS request_day
  FROM buyback_requests br
  WHERE br.status = 'pending'
  ORDER BY br.user_id, br.request_date ASC   -- 重複申請は最も古いものを採用
)
SELECT
  nm.id                                                   AS nft_id,
  pr.user_id,
  dyl.date,
  (dyl.distribution_dividend / dyl.total_nft_count)       AS daily_profit
FROM pending_req pr
JOIN users u ON u.user_id = pr.user_id
JOIN daily_yield_log_v2 dyl
  ON dyl.date <= pr.request_day
 AND dyl.date >  pr.request_day - INTERVAL '15 days'
 AND dyl.total_nft_count > 0
JOIN nft_master nm
  ON nm.user_id = pr.user_id
 AND nm.buyback_date IS NULL
 AND nm.operation_start_date IS NOT NULL
 AND nm.operation_start_date <= dyl.date
WHERE u.has_approved_nft = true
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  -- 既に配布済みの日は対象外（二重配布防止）
  AND NOT EXISTS (
    SELECT 1 FROM nft_daily_profit ndp
    WHERE ndp.user_id = pr.user_id AND ndp.date = dyl.date
  );

-- 確認: 想定は 46名 / 合計 $92.77
SELECT
  COUNT(DISTINCT user_id)                       AS 対象人数,
  COUNT(DISTINCT (user_id, date))               AS ユーザー日数,
  COUNT(*)                                      AS 挿入行数,
  ROUND(SUM(daily_profit)::numeric, 2)          AS 補填総額
FROM backfill_buyback_20260905;

-- ユーザー別
SELECT user_id,
       COUNT(DISTINCT date)                     AS 日数,
       COUNT(*)                                 AS 行数,
       ROUND(SUM(daily_profit)::numeric, 3)     AS 補填額
FROM backfill_buyback_20260905
GROUP BY user_id
ORDER BY SUM(daily_profit) DESC;

-- 補填でマイナス残高になる人がいないか（マイナス日利の補填があるため）
SELECT b.user_id,
       ROUND(ac.available_usdt::numeric, 2)                        AS 現在残高,
       ROUND(SUM(b.daily_profit)::numeric, 3)                      AS 補填額,
       ROUND((ac.available_usdt + SUM(b.daily_profit))::numeric, 2) AS 補填後残高
FROM backfill_buyback_20260905 b
JOIN affiliate_cycle ac ON ac.user_id = b.user_id
GROUP BY b.user_id, ac.available_usdt
HAVING (ac.available_usdt + SUM(b.daily_profit)) < 0
ORDER BY 4;


-- ============================================================
-- STEP 2: 本処理（★STEP 1 の件数・金額を確認してから実行★）
-- ============================================================
BEGIN;

-- 2-1) nft_daily_profit へ補填レコードを挿入
INSERT INTO nft_daily_profit (
  nft_id, user_id, date, daily_profit,
  yield_rate, user_rate, base_amount, phase, created_at
)
SELECT
  b.nft_id, b.user_id, b.date, b.daily_profit,
  NULL, NULL, 1000, 'DIVIDEND', NOW()
FROM backfill_buyback_20260905 b;

-- 2-2) available_usdt に加算
--   ★実際に格納された値を読み戻して加算する（丸め差を出さないため）
UPDATE affiliate_cycle ac
SET available_usdt = ac.available_usdt + s.amount,
    updated_at = NOW()
FROM (
  SELECT ndp.user_id, SUM(ndp.daily_profit) AS amount
  FROM nft_daily_profit ndp
  JOIN backfill_buyback_20260905 b
    ON b.nft_id = ndp.nft_id AND b.date = ndp.date
  GROUP BY ndp.user_id
) s
WHERE ac.user_id = s.user_id;

COMMIT;


-- ============================================================
-- STEP 3: 検証
-- ============================================================
-- 3-1) 挿入結果
SELECT
  COUNT(DISTINCT ndp.user_id)                   AS 対象人数,
  COUNT(*)                                      AS 挿入行数,
  ROUND(SUM(ndp.daily_profit)::numeric, 2)      AS 補填総額
FROM nft_daily_profit ndp
JOIN backfill_buyback_20260905 b
  ON b.nft_id = ndp.nft_id AND b.date = ndp.date;

-- 3-2) A512FF の確認（8/16・8/17 に8枚ずつ、合計 $8.20 になるはず）
SELECT date, COUNT(*) AS 枚数, ROUND(SUM(daily_profit)::numeric, 3) AS 受取額
FROM nft_daily_profit
WHERE user_id = 'A512FF' AND date >= '2026-08-14'
GROUP BY date ORDER BY date;

-- 3-3) 取りこぼしが解消したか（0件になるはず）
WITH pending_req AS (
  SELECT DISTINCT ON (br.user_id)
    br.user_id, (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS request_day
  FROM buyback_requests br WHERE br.status = 'pending'
  ORDER BY br.user_id, br.request_date ASC
)
SELECT COUNT(*) AS 残りの未配布
FROM pending_req pr
JOIN users u ON u.user_id = pr.user_id
JOIN daily_yield_log_v2 dyl
  ON dyl.date <= pr.request_day AND dyl.date > pr.request_day - INTERVAL '15 days'
WHERE u.has_approved_nft = true
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND EXISTS (SELECT 1 FROM nft_master nm
               WHERE nm.user_id = pr.user_id AND nm.buyback_date IS NULL
                 AND nm.operation_start_date IS NOT NULL
                 AND nm.operation_start_date <= dyl.date)
  AND NOT EXISTS (SELECT 1 FROM nft_daily_profit ndp
                   WHERE ndp.user_id = pr.user_id AND ndp.date = dyl.date);

-- 3-4) マイナス残高になった人
SELECT user_id, ROUND(available_usdt::numeric, 2) AS available_usdt
FROM affiliate_cycle
WHERE available_usdt < -0.01
ORDER BY available_usdt;


-- ============================================================
-- 【ロールバック】STEP 2 を取り消す場合
-- ============================================================
-- BEGIN;
-- UPDATE affiliate_cycle ac
-- SET available_usdt = ac.available_usdt - s.amount, updated_at = NOW()
-- FROM (
--   SELECT ndp.user_id, SUM(ndp.daily_profit) AS amount
--   FROM nft_daily_profit ndp
--   JOIN backfill_buyback_20260905 b ON b.nft_id = ndp.nft_id AND b.date = ndp.date
--   GROUP BY ndp.user_id
-- ) s
-- WHERE ac.user_id = s.user_id;
--
-- DELETE FROM nft_daily_profit ndp
-- USING backfill_buyback_20260905 b
-- WHERE b.nft_id = ndp.nft_id AND b.date = ndp.date;
-- COMMIT;
