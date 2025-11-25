-- ============================================================
-- 本番環境の完全なスキーマをテスト環境用にエクスポート
-- ============================================================
-- 
-- 使い方:
-- 1. 本番Supabaseの SQL Editor でこのスクリプトを実行
-- 2. 各セクションの結果をコピー
-- 3. テスト環境のSupabaseで順番に実行
--
-- ============================================================

-- ============================================================
-- STEP 1: テーブル定義のエクスポート
-- ============================================================
-- 
-- 手動で各テーブルのCREATE TABLE文を取得する必要があります
-- Supabase Dashboard > Table Editor > 各テーブル > "..." > "View SQL Definition"
--
-- または以下のクエリでテーブル一覧を確認:

SELECT 
    tablename,
    schemaname
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================
-- STEP 2: すべてのRPC関数をエクスポート
-- ============================================================

-- このクエリですべての関数定義を取得できます:

SELECT 
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.prokind = 'f'  -- 'f' = function, 'p' = procedure
ORDER BY p.proname;

-- ============================================================
-- STEP 3: インデックスのエクスポート
-- ============================================================

SELECT 
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname NOT LIKE '%_pkey'  -- 主キーは除外（自動作成される）
ORDER BY tablename, indexname;

-- ============================================================
-- STEP 4: RLS (Row Level Security) ポリシーのエクスポート
-- ============================================================

SELECT 
    'ALTER TABLE ' || schemaname || '.' || tablename || ' ENABLE ROW LEVEL SECURITY;' AS enable_rls
FROM pg_tables
WHERE schemaname = 'public'
AND rowsecurity = true;

-- 各テーブルのポリシー詳細:
SELECT 
    schemaname,
    tablename,
    policyname,
    'CREATE POLICY "' || policyname || '" ON ' || schemaname || '.' || tablename || 
    ' AS ' || CASE WHEN permissive = 'PERMISSIVE' THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END ||
    ' FOR ' || cmd ||
    ' TO ' || array_to_string(roles, ', ') ||
    COALESCE(' USING (' || qual || ')', '') ||
    COALESCE(' WITH CHECK (' || with_check || ')', '') ||
    ';' AS policy_statement
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================
-- STEP 5: トリガーのエクスポート
-- ============================================================

SELECT 
    'CREATE TRIGGER ' || trigger_name ||
    ' ' || action_timing ||
    ' ' || string_agg(event_manipulation, ' OR ') ||
    ' ON ' || event_object_schema || '.' || event_object_table ||
    ' FOR EACH ' || action_orientation ||
    ' ' || action_statement || ';' AS trigger_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
GROUP BY trigger_name, action_timing, event_object_schema, event_object_table, action_orientation, action_statement
ORDER BY event_object_table, trigger_name;

-- ============================================================
-- STEP 6: シーケンスのエクスポート
-- ============================================================

SELECT 
    'CREATE SEQUENCE IF NOT EXISTS ' || sequence_name || 
    ' START ' || start_value ||
    ' INCREMENT ' || increment ||
    ';' AS sequence_statement
FROM information_schema.sequences
WHERE sequence_schema = 'public';

-- ============================================================
-- STEP 7: ビューのエクスポート
-- ============================================================

SELECT 
    'CREATE OR REPLACE VIEW ' || table_name || ' AS ' || view_definition || ';' AS view_statement
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- ============================================================
-- 完了
-- ============================================================
-- 
-- 次のステップ:
-- 1. テスト用Supabaseプロジェクトを作成
-- 2. STEP 1-7 の結果を順番にテスト環境で実行
-- 3. .env.test.local を作成して接続情報を設定
-- 4. データのコピー（オプション）
--
-- ============================================================
