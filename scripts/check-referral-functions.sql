-- ========================================
-- 紹介報酬関連の関数を確認
-- ========================================

SELECT '=== 1. referralまたはrewardを含む関数一覧 ===' as section;

SELECT
    proname as function_name,
    pronargs as num_args,
    pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc
WHERE proname ILIKE '%referral%'
   OR proname ILIKE '%reward%'
ORDER BY proname;

SELECT '=== 2. 日利処理関数の定義を確認 ===' as section;

-- process_daily_yield_with_cycles関数の定義を表示
SELECT pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles'
LIMIT 1;

SELECT '=== 3. 紹介報酬の計算方法を確認 ===' as section;

-- cum_usdtの増加（紹介報酬）がどのように計算されているか
SELECT
    '現在のシステムでは、紹介報酬は日利処理の中で' as note,
    '個別に計算されているか、別の方法で処理されている可能性があります' as status;

SELECT '=== 完了 ===' as section;
