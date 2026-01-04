-- ========================================
-- 177B83の完全履歴調査
-- ========================================

-- 1. ユーザー情報
SELECT '=== ユーザー情報 ===' as section;
SELECT user_id, email, operation_start_date, has_approved_nft
FROM users WHERE user_id = '177B83';

-- 2. NFT一覧
SELECT '=== NFT一覧 ===' as section;
SELECT id, nft_type, acquired_date, buyback_date
FROM nft_master WHERE user_id = '177B83';

-- 3. 出金履歴詳細
SELECT '=== 出金履歴詳細 ===' as section;
SELECT withdrawal_month, total_amount, personal_amount, referral_amount, status, created_at
FROM monthly_withdrawals WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 4. 紹介報酬履歴
SELECT '=== 紹介報酬履歴 ===' as section;
SELECT year_month, SUM(profit_amount) as monthly_referral
FROM monthly_referral_profit WHERE user_id = '177B83'
GROUP BY year_month ORDER BY year_month;

-- 5. affiliate_cycle詳細
SELECT '=== affiliate_cycle詳細 ===' as section;
SELECT * FROM affiliate_cycle WHERE user_id = '177B83';

-- 6. 個人利益月別
SELECT '=== 個人利益月別 ===' as section;
SELECT 
  DATE_TRUNC('month', date) as month,
  SUM(daily_profit) as monthly_profit
FROM nft_daily_profit WHERE user_id = '177B83'
GROUP BY DATE_TRUNC('month', date)
ORDER BY month;
