-- ========================================
-- 59C23Cのavailable_usdt = -$8.15 の原因調査
-- ========================================

-- 1. affiliate_cycle詳細
SELECT '=== affiliate_cycle詳細 ===' as section;
SELECT *
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 2. 全nft_daily_profit履歴
SELECT '=== nft_daily_profit全履歴 ===' as section;
SELECT date, SUM(daily_profit) as daily_total
FROM nft_daily_profit
WHERE user_id = '59C23C'
GROUP BY date
ORDER BY date;

-- 3. 個人利益合計
SELECT '=== 個人利益合計 ===' as section;
SELECT SUM(daily_profit) as total_personal_profit
FROM nft_daily_profit
WHERE user_id = '59C23C';

-- 4. 紹介報酬履歴
SELECT '=== 紹介報酬履歴 ===' as section;
SELECT year_month, SUM(profit_amount) as monthly_referral
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY year_month
ORDER BY year_month;

-- 5. 紹介報酬合計
SELECT '=== 紹介報酬合計 ===' as section;
SELECT SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE user_id = '59C23C';

-- 6. 出金履歴
SELECT '=== 出金履歴 ===' as section;
SELECT withdrawal_month, total_amount, personal_amount, referral_amount, status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY withdrawal_month;

-- 7. 出金合計
SELECT '=== 出金合計 ===' as section;
SELECT SUM(total_amount) as total_withdrawn
FROM monthly_withdrawals
WHERE user_id = '59C23C'
AND status IN ('completed', 'pending');

-- 8. 計算確認
-- available_usdt = 個人利益合計 + 紹介報酬（USDT分） - 出金済み - HOLD分
SELECT '=== 計算確認 ===' as section;
SELECT
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '59C23C') as personal_total,
  (SELECT COALESCE(SUM(profit_amount), 0) FROM monthly_referral_profit WHERE user_id = '59C23C') as referral_total,
  (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed') as withdrawn,
  (SELECT cum_usdt FROM affiliate_cycle WHERE user_id = '59C23C') as cum_usdt,
  (SELECT available_usdt FROM affiliate_cycle WHERE user_id = '59C23C') as available_usdt;
