-- ========================================
-- available_usdt問題の診断（読み取りのみ）
-- ========================================
-- 修正前に実行して現状を把握する
-- ========================================

-- 1. 177B83と59C23Cの現在のaffiliate_cycle状態
SELECT '=== 1. affiliate_cycle現在の状態 ===' as section;
SELECT
  user_id,
  ROUND(available_usdt::numeric, 2) as available_usdt,
  ROUND(cum_usdt::numeric, 2) as cum_usdt,
  phase,
  ROUND(COALESCE(withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id IN ('177B83', '59C23C')
ORDER BY user_id;

-- 2. 全出金履歴（177B83）
SELECT '=== 2. 全出金履歴（177B83）===' as section;
SELECT
  id,
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total,
  created_at::date
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 3. 全出金履歴（59C23C）
SELECT '=== 3. 全出金履歴（59C23C）===' as section;
SELECT
  id,
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total,
  created_at::date
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY withdrawal_month;

-- 4. 月別日利詳細（177B83）
SELECT '=== 4. 月別日利（177B83）===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  COUNT(*) as days,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit,
  ROUND(MIN(daily_profit)::numeric, 2) as min_day,
  ROUND(MAX(daily_profit)::numeric, 2) as max_day
FROM nft_daily_profit
WHERE user_id = '177B83'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- 5. 月別日利詳細（59C23C）
SELECT '=== 5. 月別日利（59C23C）===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  COUNT(*) as days,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit,
  ROUND(MIN(daily_profit)::numeric, 2) as min_day,
  ROUND(MAX(daily_profit)::numeric, 2) as max_day
FROM nft_daily_profit
WHERE user_id = '59C23C'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- 6. 日利合計 vs 出金合計の計算（177B83）
SELECT '=== 6. 日利 vs 出金計算（177B83）===' as section;
SELECT
  (SELECT ROUND(SUM(daily_profit)::numeric, 2) FROM nft_daily_profit WHERE user_id = '177B83') as "日利合計（全期間）",
  (SELECT ROUND(SUM(
    CASE
      WHEN personal_amount IS NOT NULL THEN personal_amount
      ELSE total_amount - COALESCE(referral_amount, 0)
    END
  )::numeric, 2) FROM monthly_withdrawals WHERE user_id = '177B83' AND status = 'completed') as "出金済み個人（計算）",
  (SELECT ROUND(SUM(total_amount)::numeric, 2) FROM monthly_withdrawals WHERE user_id = '177B83' AND status = 'completed') as "出金済みtotal（参考）";

-- 7. 日利合計 vs 出金合計の計算（59C23C）
SELECT '=== 7. 日利 vs 出金計算（59C23C）===' as section;
SELECT
  (SELECT ROUND(SUM(daily_profit)::numeric, 2) FROM nft_daily_profit WHERE user_id = '59C23C') as "日利合計（全期間）",
  (SELECT ROUND(SUM(
    CASE
      WHEN personal_amount IS NOT NULL THEN personal_amount
      ELSE total_amount - COALESCE(referral_amount, 0)
    END
  )::numeric, 2) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed') as "出金済み個人（計算）",
  (SELECT ROUND(SUM(total_amount)::numeric, 2) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed') as "出金済みtotal（参考）";

-- 8. 月次紹介報酬（monthly_referral_profit）確認
SELECT '=== 8. 月次紹介報酬（177B83）===' as section;
SELECT
  year_month,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as referral_profit
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month
ORDER BY year_month;

SELECT '=== 8. 月次紹介報酬（59C23C）===' as section;
SELECT
  year_month,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as referral_profit
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY year_month
ORDER BY year_month;

-- 9. pending出金の期待値との比較
SELECT '=== 9. pending出金 vs 期待値 ===' as section;
SELECT
  mw.user_id,
  mw.withdrawal_month,
  ROUND(COALESCE(mw.personal_amount, 0)::numeric, 2) as "pending個人",
  ROUND(COALESCE(jan.jan_profit, 0)::numeric, 2) as "1月日利合計",
  ROUND(COALESCE(feb.feb_profit, 0)::numeric, 2) as "2月日利合計"
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as jan_profit
  FROM nft_daily_profit
  WHERE date >= '2026-01-01' AND date < '2026-02-01'
  GROUP BY user_id
) jan ON mw.user_id = jan.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as feb_profit
  FROM nft_daily_profit
  WHERE date >= '2026-02-01'
  GROUP BY user_id
) feb ON mw.user_id = feb.user_id
WHERE mw.status = 'pending'
  AND mw.user_id IN ('177B83', '59C23C');

-- 10. 問題のあるユーザー数
SELECT '=== 10. マイナスavailable_usdtユーザー ===' as section;
SELECT
  COUNT(*) as "マイナスユーザー数",
  ROUND(SUM(available_usdt)::numeric, 2) as "マイナス合計",
  ROUND(MIN(available_usdt)::numeric, 2) as "最小値"
FROM affiliate_cycle
WHERE available_usdt < 0;

SELECT '診断完了 - UPDATEは実行していません' as note;
