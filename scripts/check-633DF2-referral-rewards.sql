-- ========================================
-- 633DF2の状態確認と紹介報酬チェック
-- ========================================

SELECT '=== 1. 633DF2の基本情報 ===' as section;

SELECT
    user_id,
    email,
    referrer_user_id,
    has_approved_nft,
    admin_approved_at::date as approved_date,
    operation_start_date,
    CURRENT_DATE - operation_start_date::date as days_since_operation_start,
    CASE
        WHEN operation_start_date IS NULL THEN '運用開始日未設定'
        WHEN CURRENT_DATE < operation_start_date::date THEN '運用開始前'
        ELSE '運用開始済み'
    END as operation_status
FROM users
WHERE user_id = '633DF2';

SELECT '=== 2. 633DF2のNFT情報 ===' as section;

SELECT
    COUNT(*) as nft_count,
    SUM(nft_value) as total_nft_value
FROM nft_master
WHERE user_id = '633DF2'
  AND buyback_date IS NULL;

SELECT '=== 3. 633DF2のaffiliate_cycle情報 ===' as section;

SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    available_usdt,
    cum_usdt,
    cycle_number
FROM affiliate_cycle
WHERE user_id = '633DF2';

SELECT '=== 4. 633DF2の日利履歴（最近10件） ===' as section;

SELECT
    date,
    daily_profit,
    yield_rate
FROM user_daily_profit
WHERE user_id = '633DF2'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 5. 7E0A1Eの直接紹介者一覧 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.operation_start_date,
    ac.total_nft_count,
    ac.available_usdt,
    CASE
        WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
        WHEN CURRENT_DATE < u.operation_start_date::date THEN '運用開始前'
        ELSE '運用開始済み'
    END as operation_status
FROM users u
LEFT JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE u.referrer_user_id = '7E0A1E'
ORDER BY u.user_id;

SELECT '=== 6. calculate_daily_referral_rewards関数の定義確認 ===' as section;

SELECT
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'calculate_daily_referral_rewards';

SELECT '=== 7. 7E0A1Eの紹介報酬履歴（最近10件） ===' as section;

SELECT
    date,
    level_1_profit,
    level_1_reward,
    level_2_profit,
    level_2_reward,
    level_3_profit,
    level_3_reward,
    total_reward
FROM daily_referral_rewards
WHERE user_id = '7E0A1E'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 8. 直接テスト: 7E0A1Eの今日の紹介報酬を計算 ===' as section;

SELECT
    referral_user_id,
    referral_level,
    referral_profit,
    referral_amount,
    calculation_date
FROM calculate_daily_referral_rewards('7E0A1E', CURRENT_DATE);

SELECT '=== 完了 ===' as section;
