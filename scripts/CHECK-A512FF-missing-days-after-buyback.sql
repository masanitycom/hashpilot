-- ============================================================
-- A512FF: 買取申請(2026-08-17 21:57 JST)以降の日利未配布分の特定
--
-- 判明済み:
--   ・NFT 8枚すべてに正しく日利が配布されていた（8/15まで）
--   ・最終配布日 2026-08-15、8/16以降は0件
--   ・買取申請 status='pending' により、日付に関係なくユーザー単位で全停止
--
-- 仕様（docs/TODO.md 2026-02-07確定）: 買取申請の翌日から日利停止
--   → 申請 8/17 なら 8/18 から停止。8/16・8/17 は支払われるべき
-- 実行日: 2026-09-05
-- ============================================================

-- ------------------------------------------------------------
-- 【1】8/14以降の日利設定と、A512FFへの配布有無
--   「配布枚数」が空の日 = 未配布
-- ------------------------------------------------------------
SELECT
  dyl.date                                       AS 日利設定日,
  ROUND(dyl.profit_per_nft::numeric, 4)          AS 一枚単価_控除前,
  ROUND((dyl.profit_per_nft * 0.42)::numeric, 4) AS 一枚あたり受取_見込,
  dyl.created_at                                 AS 日利入力日時,
  COUNT(ndp.id)                                  AS A512FF配布枚数,
  ROUND(SUM(ndp.daily_profit)::numeric, 3)       AS A512FF受取額,
  CASE WHEN COUNT(ndp.id) = 0 THEN '★未配布' ELSE '' END AS 判定
FROM daily_yield_log_v2 dyl
LEFT JOIN nft_daily_profit ndp
       ON ndp.date = dyl.date AND ndp.user_id = 'A512FF'
WHERE dyl.date >= '2026-08-14'
GROUP BY dyl.date, dyl.profit_per_nft, dyl.created_at
ORDER BY dyl.date;


-- ------------------------------------------------------------
-- 【2】仕様どおり（8/18から停止）なら支払うべきだった額
--   対象: 8/16 と 8/17 の2日分 × 8枚
-- ------------------------------------------------------------
SELECT
  COUNT(*)                                                  AS 対象日数,
  ROUND(SUM(dyl.profit_per_nft * 0.42 * 8)::numeric, 3)     AS 補填すべき額
FROM daily_yield_log_v2 dyl
WHERE dyl.date IN ('2026-08-16', '2026-08-17')
  AND NOT EXISTS (
    SELECT 1 FROM nft_daily_profit ndp
    WHERE ndp.user_id = 'A512FF' AND ndp.date = dyl.date
  );

-- 日別の内訳
SELECT
  dyl.date,
  ROUND(dyl.profit_per_nft::numeric, 4)                 AS 一枚単価_控除前,
  ROUND((dyl.profit_per_nft * 0.42)::numeric, 4)        AS 一枚あたり,
  ROUND((dyl.profit_per_nft * 0.42 * 8)::numeric, 3)    AS 八枚分
FROM daily_yield_log_v2 dyl
WHERE dyl.date IN ('2026-08-16', '2026-08-17')
ORDER BY dyl.date;


-- ------------------------------------------------------------
-- 【3】同じ問題を抱えている他のユーザーがいないか
--   買取申請が pending で、申請日の前日以前の日利が抜けている人
-- ------------------------------------------------------------
SELECT
  br.user_id,
  br.request_date::date                     AS 申請日,
  br.status,
  br.total_nft_count                        AS 申請枚数,
  MAX(ndp.date)                             AS 最終配布日,
  (br.request_date::date - MAX(ndp.date))   AS 申請日との差_日,
  CASE
    WHEN MAX(ndp.date) < br.request_date::date THEN '★申請日より前に止まっている'
    ELSE ''
  END                                       AS 判定
FROM buyback_requests br
LEFT JOIN nft_daily_profit ndp ON ndp.user_id = br.user_id
WHERE br.status = 'pending'
GROUP BY br.user_id, br.request_date, br.status, br.total_nft_count
ORDER BY br.request_date DESC;


-- ------------------------------------------------------------
-- 【4】参考: 2枚(通番7,8)の運用開始日が正しいかの確認
--   purchases.admin_approved_at = 2026-03-08 だが created_at = 2026-03-23
--   → 承認日が手動で過去に書き換えられている（BUG_HISTORY記載の事案）
--   nft_master.acquired_date = 2026-03-27 → OSD 2026-04-15（ルールどおり）
--   金額影響なし（日利は nft_master 側で判定するため）
-- ------------------------------------------------------------
SELECT
  p.id, p.nft_quantity, p.amount_usd,
  p.created_at            AS 申請日時,
  p.admin_approved_at     AS 承認日時,
  CASE WHEN p.admin_approved_at < p.created_at
       THEN '★承認日が申請日より前（書き換えの痕跡）' ELSE '' END AS 判定
FROM purchases p
WHERE p.user_id = 'A512FF'
ORDER BY p.created_at;
