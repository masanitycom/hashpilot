-- ========================================
-- 9/27の日利が月末処理の後（10/2）に入力された影響の確認
-- ========================================
-- 経緯:
--   10/01 08:23 UTC  9/30の日利入力 → 月末処理が自動実行（出金レコード・紹介報酬を作成）
--   10/02 03:31 UTC  9/27の日利を後から入力（1枚あたり $0.563、948枚、計 $533.72）
-- → 9月の出金レコードと紹介報酬には 9/27分が入っていない
-- ========================================

-- 1. 9月出金レコードの状況（作成日時・ステータス別）
SELECT
  status,
  COUNT(*) AS 件数,
  ROUND(SUM(total_amount)::numeric, 2) AS 出金合計,
  ROUND(SUM(personal_amount)::numeric, 2) AS 個人利益合計,
  ROUND(SUM(referral_amount)::numeric, 2) AS 紹介報酬合計,
  MIN(created_at) AS 最初の作成,
  MAX(created_at) AS 最後の作成
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-09-01'
GROUP BY status;

-- 2. 全体の差額（出金レコード vs 現在の残高・9月日利）
WITH sep AS (
  SELECT user_id,
         SUM(daily_profit) AS sep_profit,
         SUM(daily_profit) FILTER (WHERE date = '2026-09-27') AS d927
  FROM nft_daily_profit
  WHERE date >= '2026-09-01' AND date <= '2026-09-30'
  GROUP BY user_id
)
SELECT
  COUNT(*) AS 出金レコード数,
  ROUND(SUM(mw.personal_amount)::numeric, 2) AS レコードの個人利益,
  ROUND(SUM(COALESCE(sep.sep_profit, 0))::numeric, 2) AS 実際の9月日利,
  ROUND(SUM(COALESCE(sep.d927, 0))::numeric, 2) AS うち9月27日分,
  ROUND(SUM(mw.total_amount)::numeric, 2) AS レコードの出金合計,
  ROUND(SUM(ac.available_usdt)::numeric, 2) AS 現在の残高合計,
  COUNT(*) FILTER (
    WHERE ABS(ac.available_usdt - mw.total_amount - COALESCE(sep.d927, 0)) < 0.02
  ) AS 残高との差が9月27日分と一致する人数
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
LEFT JOIN sep ON sep.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-09-01';

-- 3. ユーザー別の明細（差額の大きい順）
WITH sep AS (
  SELECT user_id,
         SUM(daily_profit) AS sep_profit,
         SUM(daily_profit) FILTER (WHERE date = '2026-09-27') AS d927
  FROM nft_daily_profit
  WHERE date >= '2026-09-01' AND date <= '2026-09-30'
  GROUP BY user_id
)
SELECT
  mw.user_id,
  mw.status,
  mw.personal_amount AS レコードの個人利益,
  ROUND(COALESCE(sep.sep_profit, 0)::numeric, 2) AS 実際の9月日利,
  ROUND(COALESCE(sep.d927, 0)::numeric, 2) AS "9月27日分",
  mw.total_amount AS レコードの出金合計,
  ac.available_usdt AS 現在の残高,
  ROUND((ac.available_usdt - mw.total_amount)::numeric, 2) AS 残高との差
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
LEFT JOIN sep ON sep.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-09-01'
ORDER BY ABS(ac.available_usdt - mw.total_amount) DESC
LIMIT 50;

-- 4. 9月分の紹介報酬の不足額（9/27分が計算に入っていない）
WITH sep AS (
  SELECT user_id, SUM(daily_profit) AS sep_profit
  FROM nft_daily_profit
  WHERE date >= '2026-09-01' AND date <= '2026-09-30'
  GROUP BY user_id
),
calc AS (
  SELECT
    mrp.user_id,
    mrp.profit_amount AS 現在の金額,
    GREATEST(0, sep.sep_profit) * CASE mrp.referral_level
      WHEN 1 THEN 0.20 WHEN 2 THEN 0.10 WHEN 3 THEN 0.05 END AS 正しい金額
  FROM monthly_referral_profit mrp
  JOIN sep ON sep.user_id = mrp.child_user_id
  WHERE mrp.year_month = '2026-09'
)
SELECT
  user_id,
  ROUND(SUM(現在の金額)::numeric, 2) AS 現在の紹介報酬,
  ROUND(SUM(正しい金額)::numeric, 2) AS 正しい紹介報酬,
  ROUND(SUM(正しい金額 - 現在の金額)::numeric, 2) AS 不足額
FROM calc
GROUP BY user_id
HAVING ABS(SUM(正しい金額 - 現在の金額)) >= 0.01
ORDER BY 不足額 DESC;
