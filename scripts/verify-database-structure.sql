-- 全テーブル構造確認（コード編集前の必須チェック）

-- 1. 全テーブル一覧
SELECT 
    '📋 データベース内の全テーブル:' as info,
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;

-- 2. 主要テーブルの詳細構造確認
-- users テーブル
SELECT 
    '👤 users テーブル構造:' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- purchases テーブル
SELECT 
    '💰 purchases テーブル構造:' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'purchases' AND table_schema = 'public'
ORDER BY ordinal_position;

-- affiliate_cycle テーブル
SELECT 
    '🔄 affiliate_cycle テーブル構造:' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'affiliate_cycle' AND table_schema = 'public'
ORDER BY ordinal_position;

-- user_daily_profit テーブル
SELECT 
    '📈 user_daily_profit テーブル構造:' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. 日利処理関連関数の確認
SELECT 
    '⚙️ 日利処理関連関数:' as function_info,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND (
    p.proname LIKE '%daily%' 
    OR p.proname LIKE '%yield%' 
    OR p.proname LIKE '%profit%'
    OR p.proname LIKE '%cycle%'
)
ORDER BY p.proname;