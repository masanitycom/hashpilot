-- ============================================================
-- テーブル定義の詳細エクスポート（手動コピー用）
-- ============================================================
--
-- 使い方:
-- 1. 本番Supabase SQL Editorでこのクエリを1つずつ実行
-- 2. 結果をコピーしてテキストファイルに保存
-- 3. テスト環境のSQL Editorで実行
--
-- ============================================================

-- ============================================================
-- STEP 1: テーブル一覧の確認
-- ============================================================

SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================
-- STEP 2: 各テーブルの完全なCREATE TABLE文を取得
-- ============================================================
--
-- 注意: PostgreSQLにはpg_get_tabledefという関数は標準では存在しません
-- 代わりに、pg_dumpを使うか、以下の方法で手動で構築します
--

-- 方法1: 列定義のみ（基本）
SELECT
    table_name,
    string_agg(
        column_name || ' ' ||
        CASE
            WHEN data_type = 'character varying' THEN 'VARCHAR(' || character_maximum_length || ')'
            WHEN data_type = 'character' THEN 'CHAR(' || character_maximum_length || ')'
            WHEN data_type = 'numeric' THEN
                CASE
                    WHEN numeric_precision IS NOT NULL AND numeric_scale IS NOT NULL
                    THEN 'NUMERIC(' || numeric_precision || ',' || numeric_scale || ')'
                    ELSE 'NUMERIC'
                END
            WHEN data_type = 'timestamp without time zone' THEN 'TIMESTAMP'
            WHEN data_type = 'timestamp with time zone' THEN 'TIMESTAMPTZ'
            WHEN data_type = 'ARRAY' THEN udt_name
            ELSE upper(data_type)
        END ||
        CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
        CASE
            WHEN column_default IS NOT NULL THEN ' DEFAULT ' || column_default
            ELSE ''
        END,
        E',\n    '
        ORDER BY ordinal_position
    ) AS columns_definition
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;

-- ============================================================
-- STEP 3: 主キー制約の取得
-- ============================================================

SELECT
    'ALTER TABLE ' || tc.table_name ||
    ' ADD CONSTRAINT ' || tc.constraint_name ||
    ' PRIMARY KEY (' ||
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) ||
    ');' AS primary_key_sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
    AND tc.table_schema = 'public'
GROUP BY tc.table_name, tc.constraint_name
ORDER BY tc.table_name;

-- ============================================================
-- STEP 4: ユニーク制約の取得
-- ============================================================

SELECT
    'ALTER TABLE ' || tc.table_name ||
    ' ADD CONSTRAINT ' || tc.constraint_name ||
    ' UNIQUE (' ||
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) ||
    ');' AS unique_constraint_sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
GROUP BY tc.table_name, tc.constraint_name
ORDER BY tc.table_name;

-- ============================================================
-- STEP 5: 外部キー制約の取得
-- ============================================================

SELECT
    'ALTER TABLE ' || tc.table_name ||
    ' ADD CONSTRAINT ' || tc.constraint_name ||
    ' FOREIGN KEY (' || kcu.column_name || ')' ||
    ' REFERENCES ' || ccu.table_name || '(' || ccu.column_name || ')' ||
    CASE
        WHEN rc.delete_rule = 'CASCADE' THEN ' ON DELETE CASCADE'
        WHEN rc.delete_rule = 'SET NULL' THEN ' ON DELETE SET NULL'
        WHEN rc.delete_rule = 'SET DEFAULT' THEN ' ON DELETE SET DEFAULT'
        WHEN rc.delete_rule = 'RESTRICT' THEN ' ON DELETE RESTRICT'
        ELSE ''
    END ||
    CASE
        WHEN rc.update_rule = 'CASCADE' THEN ' ON UPDATE CASCADE'
        WHEN rc.update_rule = 'SET NULL' THEN ' ON UPDATE SET NULL'
        WHEN rc.update_rule = 'SET DEFAULT' THEN ' ON UPDATE SET DEFAULT'
        WHEN rc.update_rule = 'RESTRICT' THEN ' ON UPDATE RESTRICT'
        ELSE ''
    END || ';' AS foreign_key_sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
LEFT JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
    AND tc.table_schema = rc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================
-- STEP 6: CHECK制約の取得
-- ============================================================

SELECT
    'ALTER TABLE ' || tc.table_name ||
    ' ADD CONSTRAINT ' || tc.constraint_name ||
    ' CHECK (' || cc.check_clause || ');' AS check_constraint_sql
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
    AND tc.table_schema = cc.constraint_schema
WHERE tc.constraint_type = 'CHECK'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================
-- STEP 7: デフォルト値の取得
-- ============================================================

SELECT
    table_name,
    column_name,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND column_default IS NOT NULL
ORDER BY table_name, ordinal_position;

-- ============================================================
-- STEP 8: インデックスの取得
-- ============================================================

SELECT
    indexdef || ';' AS index_sql
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname NOT LIKE '%_pkey'  -- 主キーは除外
    AND indexname NOT LIKE '%_key'   -- ユニーク制約は除外
ORDER BY tablename, indexname;

-- ============================================================
-- STEP 9: シーケンスの取得
-- ============================================================

SELECT
    sequence_name,
    data_type,
    start_value,
    minimum_value,
    maximum_value,
    increment
FROM information_schema.sequences
WHERE sequence_schema = 'public'
ORDER BY sequence_name;

-- ============================================================
-- STEP 10: トリガーの取得
-- ============================================================

SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============================================================
-- 完了
-- ============================================================
--
-- 次のステップ:
-- 1. 各STEPの結果をテキストファイルに保存
-- 2. テスト環境でCREATE TABLE文を手動作成
-- 3. 制約を順番に追加
-- 4. RPC関数をインポート
-- 5. RLSポリシーを設定
--
-- ============================================================
