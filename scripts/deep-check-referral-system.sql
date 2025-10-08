-- ========================================
-- 紹介報酬システムの詳細確認
-- ========================================

SELECT '=== 1. すべての関数一覧 ===' as section;

SELECT
    proname as function_name,
    pronargs as num_args
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

SELECT '=== 2. cum_usdtの増加履歴を確認 ===' as section;

-- 7E0A1Eのcum_usdtの現在値
SELECT
    user_id,
    cum_usdt,
    available_usdt,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 3. 633DF2のNFT日利が計算されているか ===' as section;

SELECT
    date,
    daily_profit,
    yield_rate
FROM nft_daily_profit
WHERE user_id = '633DF2'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 4. 紹介報酬がどこで計算されているか ===' as section;

-- process_daily_yield_with_cycles関数の中身を確認（紹介報酬計算部分のみ）
SELECT
    '関数定義を確認する必要があります' as note,
    'process_daily_yield_with_cycles関数の中で' as where_to_check,
    'calculate_daily_referral_rewardsが呼ばれているはず' as expected;

SELECT '=== 5. Level 1紹介者（7E0A1Eの直接紹介）を確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.operation_start_date,
    ac.total_nft_count,
    ac.cum_usdt,
    CASE
        WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
        WHEN CURRENT_DATE < u.operation_start_date THEN '運用開始前'
        ELSE '運用開始済み'
    END as status
FROM users u
LEFT JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE u.referrer_user_id = '7E0A1E'
  AND u.has_approved_nft = true
ORDER BY u.operation_start_date NULLS FIRST;

SELECT '=== 完了 ===' as section;
