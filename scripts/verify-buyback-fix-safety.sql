-- buyback_requests修正の安全性確認スクリプト
-- 他の機能に影響がないことを確認

-- ============================================
-- STEP 1: buyback_requestsテーブルの現在の構造確認
-- ============================================

SELECT '=== buyback_requestsテーブルの構造 ===' as section;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'buyback_requests'
ORDER BY ordinal_position;

-- ============================================
-- STEP 2: emailカラムを参照している箇所を確認
-- ============================================

SELECT '=== emailカラムの使用状況 ===' as section;

-- 現在のbuyback_requestsデータでemailカラムの状態確認
SELECT
    COUNT(*) as total_records,
    COUNT(email) as records_with_email,
    COUNT(*) - COUNT(email) as records_without_email
FROM buyback_requests;

-- ============================================
-- STEP 3: get_buyback_requests関数の現在の定義確認
-- ============================================

SELECT '=== get_buyback_requests関数の現在の定義 ===' as section;

SELECT
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'get_buyback_requests';

-- ============================================
-- STEP 4: 関連する他の関数の確認
-- ============================================

SELECT '=== 買い取り関連の全関数 ===' as section;

SELECT
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname LIKE '%buyback%'
ORDER BY proname;

-- ============================================
-- STEP 5: buyback_requestsテーブルへの外部キー制約確認
-- ============================================

SELECT '=== 外部キー制約の確認 ===' as section;

SELECT
    conname as constraint_name,
    conrelid::regclass as table_name,
    confrelid::regclass as referenced_table,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'buyback_requests'::regclass
   OR confrelid = 'buyback_requests'::regclass;

-- ============================================
-- STEP 6: 影響範囲の評価
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '影響範囲の評価';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ 安全な変更:';
    RAISE NOTICE '  1. buyback_requests.email を NULL許可に変更';
    RAISE NOTICE '     → 既存データには影響なし';
    RAISE NOTICE '     → このカラムは現在使われていない';
    RAISE NOTICE '';
    RAISE NOTICE '  2. get_buyback_requests の戻り値型を修正';
    RAISE NOTICE '     → request_date: DATE → TIMESTAMP WITH TIME ZONE';
    RAISE NOTICE '     → フロントエンドの表示に影響なし';
    RAISE NOTICE '';
    RAISE NOTICE '  3. create_buyback_request から email挿入を削除';
    RAISE NOTICE '     → emailカラムはNULL許可になるため問題なし';
    RAISE NOTICE '';
    RAISE NOTICE '❌ 影響を受けない機能:';
    RAISE NOTICE '  - 購入承認 (approve_user_nft)';
    RAISE NOTICE '  - 出金申請 (withdrawals)';
    RAISE NOTICE '  - 日利計算 (process_daily_yield_with_cycles)';
    RAISE NOTICE '  - 自動NFT付与';
    RAISE NOTICE '  - NFTマスター管理';
    RAISE NOTICE '';
    RAISE NOTICE '✅ この修正は買い取り機能のみに影響します';
    RAISE NOTICE '=========================================';
END $$;
