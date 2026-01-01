-- ========================================
-- daily_yield_log_v2 テーブルのデータ確認
-- ========================================

-- 1. テーブル存在確認
SELECT '=== 1. テーブル存在確認 ===' as section;
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'daily_yield_log_v2';

-- 2. 全データ確認
SELECT '=== 2. daily_yield_log_v2の全データ ===' as section;
SELECT * FROM daily_yield_log_v2 ORDER BY date DESC;

-- 3. レコード数
SELECT '=== 3. レコード数 ===' as section;
SELECT COUNT(*) as total_records FROM daily_yield_log_v2;

-- 4. RLSポリシー確認
SELECT '=== 4. RLSポリシー確認 ===' as section;
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'daily_yield_log_v2';

-- 5. RLS有効/無効確認
SELECT '=== 5. RLS状態確認 ===' as section;
SELECT
    relname as table_name,
    relrowsecurity as rls_enabled,
    relforcerowsecurity as rls_forced
FROM pg_class
WHERE relname = 'daily_yield_log_v2';
