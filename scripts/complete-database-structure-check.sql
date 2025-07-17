-- 🔍 HASHPILOT データベース構造の完全確認
-- 実行日: 2025-07-16

-- 1. 全テーブル一覧
SELECT 
    '📋 全テーブル一覧' as section,
    table_name,
    table_type,
    CASE WHEN table_name IN ('users', 'purchases', 'affiliate_cycle', 'user_daily_profit', 'admins', 'daily_yield_log', 'withdrawal_requests') 
         THEN '⭐ 重要' 
         ELSE '📦 その他' 
    END as importance
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY importance, table_name;

-- 2. 主要テーブルの詳細構造確認

-- 👤 users テーブル
SELECT 
    '👤 users テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 💰 purchases テーブル
SELECT 
    '💰 purchases テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'purchases' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 🔄 affiliate_cycle テーブル
SELECT 
    '🔄 affiliate_cycle テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'affiliate_cycle' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 📈 user_daily_profit テーブル
SELECT 
    '📈 user_daily_profit テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 👨‍💼 admins テーブル
SELECT 
    '👨‍💼 admins テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'admins' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 📊 daily_yield_log テーブル
SELECT 
    '📊 daily_yield_log テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 💳 withdrawal_requests テーブル
SELECT 
    '💳 withdrawal_requests テーブル構造' as section,
    ordinal_position,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'withdrawal_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. 制約とインデックスの確認

-- 🔐 ユニーク制約
SELECT 
    '🔐 ユニーク制約' as section,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public' 
    AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
    AND tc.table_name IN ('users', 'purchases', 'affiliate_cycle', 'user_daily_profit', 'admins', 'daily_yield_log', 'withdrawal_requests')
ORDER BY tc.table_name, tc.constraint_type;

-- 🔗 外部キー制約
SELECT 
    '🔗 外部キー制約' as section,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_schema = 'public'
    AND tc.table_name IN ('users', 'purchases', 'affiliate_cycle', 'user_daily_profit', 'admins', 'daily_yield_log', 'withdrawal_requests')
ORDER BY tc.table_name;

-- 📋 インデックス一覧
SELECT 
    '📋 インデックス一覧' as section,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('users', 'purchases', 'affiliate_cycle', 'user_daily_profit', 'admins', 'daily_yield_log', 'withdrawal_requests')
ORDER BY tablename, indexname;

-- 4. ストアド関数とプロシージャ

-- ⚙️ 日利処理関連関数
SELECT 
    '⚙️ 日利処理関連関数' as section,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    CASE WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
         WHEN p.provolatile = 's' THEN 'STABLE'
         WHEN p.provolatile = 'v' THEN 'VOLATILE'
    END as volatility
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%daily%' 
        OR p.proname LIKE '%yield%' 
        OR p.proname LIKE '%profit%'
        OR p.proname LIKE '%cycle%'
        OR p.proname = 'process_daily_yield_with_cycles'
    )
ORDER BY p.proname;

-- 🔧 管理者関連関数
SELECT 
    '🔧 管理者関連関数' as section,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%admin%' 
        OR p.proname LIKE '%withdrawal%'
        OR p.proname = 'is_admin'
    )
ORDER BY p.proname;

-- 🌐 その他の重要な関数
SELECT 
    '🌐 その他の重要な関数' as section,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%referral%' 
        OR p.proname LIKE '%batch%'
        OR p.proname LIKE '%log%'
    )
ORDER BY p.proname;

-- 5. RLSポリシー確認
SELECT 
    '🛡️ RLSポリシー' as section,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename IN ('users', 'purchases', 'affiliate_cycle', 'user_daily_profit', 'admins', 'daily_yield_log', 'withdrawal_requests')
ORDER BY tablename, policyname;

-- 6. 重要なサンプルデータ

-- user_daily_profit テーブルの重複チェック
SELECT 
    '❗ user_daily_profit 重複データ確認' as section,
    user_id,
    date,
    COUNT(*) as count
FROM user_daily_profit
GROUP BY user_id, date
HAVING COUNT(*) > 1
ORDER BY count DESC
LIMIT 10;

-- affiliate_cycle テーブルのサンプル
SELECT 
    '🔄 affiliate_cycle サンプルデータ' as section,
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    available_usdt,
    next_action,
    cycle_number
FROM affiliate_cycle
ORDER BY updated_at DESC
LIMIT 5;

-- users テーブルのサンプル（管理者除く）
SELECT 
    '👤 users サンプルデータ' as section,
    user_id,
    email,
    referrer_user_id,
    total_purchases,
    has_approved_nft,
    is_active
FROM users
WHERE email NOT LIKE '%@gmail.com' OR email LIKE '%+%@gmail.com'
ORDER BY created_at DESC
LIMIT 5;

-- 管理者アカウント一覧
SELECT 
    '👨‍💼 管理者アカウント一覧' as section,
    email,
    role,
    is_active,
    created_at
FROM admins
WHERE is_active = true
ORDER BY created_at;