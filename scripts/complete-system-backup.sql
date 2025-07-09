-- 完全なシステムバックアップ（現在の状況を保存）

-- 1. 全ユーザーデータのバックアップ
CREATE TABLE IF NOT EXISTS backup_users_20250706 AS
SELECT 
    id,
    user_id,
    email,
    full_name,
    referrer_user_id,
    coinw_uid,
    created_at,
    updated_at,
    is_active,
    has_approved_nft,
    total_purchases,
    total_referral_earnings
FROM users;

-- 2. auth.usersのメタデータバックアップ
CREATE TABLE IF NOT EXISTS backup_auth_users_metadata_20250706 AS
SELECT 
    id,
    email,
    raw_user_meta_data,
    created_at,
    email_confirmed_at,
    last_sign_in_at
FROM auth.users;

-- 3. 購入データのバックアップ
CREATE TABLE IF NOT EXISTS backup_purchases_20250706 AS
SELECT * FROM purchases;

-- 4. 現在の問題のあるユーザーの詳細バックアップ
CREATE TABLE IF NOT EXISTS backup_problem_users_20250706 AS
SELECT 
    u.id,
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    u.created_at,
    u.updated_at,
    au.raw_user_meta_data,
    'missing_coinw_uid' as issue_type
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NULL;

-- 5. バックアップ確認
SELECT 
    'backup_verification' as check_type,
    'backup_users_20250706' as table_name,
    COUNT(*) as record_count
FROM backup_users_20250706
UNION ALL
SELECT 
    'backup_verification' as check_type,
    'backup_auth_users_metadata_20250706' as table_name,
    COUNT(*) as record_count
FROM backup_auth_users_metadata_20250706
UNION ALL
SELECT 
    'backup_verification' as check_type,
    'backup_purchases_20250706' as table_name,
    COUNT(*) as record_count
FROM backup_purchases_20250706
UNION ALL
SELECT 
    'backup_verification' as check_type,
    'backup_problem_users_20250706' as table_name,
    COUNT(*) as record_count
FROM backup_problem_users_20250706;

-- 6. 現在の状況の詳細レポート
SELECT 
    'current_system_status' as report_type,
    'Total Users' as metric,
    COUNT(*)::text as value
FROM users
UNION ALL
SELECT 
    'current_system_status' as report_type,
    'Users with CoinW UID' as metric,
    COUNT(*)::text as value
FROM users WHERE coinw_uid IS NOT NULL
UNION ALL
SELECT 
    'current_system_status' as report_type,
    'Users with Referrer' as metric,
    COUNT(*)::text as value
FROM users WHERE referrer_user_id IS NOT NULL
UNION ALL
SELECT 
    'current_system_status' as report_type,
    'Users Missing CoinW UID' as metric,
    COUNT(*)::text as value
FROM users WHERE coinw_uid IS NULL
UNION ALL
SELECT 
    'current_system_status' as report_type,
    'Total Purchases' as metric,
    COUNT(*)::text as value
FROM purchases
UNION ALL
SELECT 
    'current_system_status' as report_type,
    'Backup Timestamp' as metric,
    NOW()::text as value;

-- 7. 問題のあるユーザーの詳細
SELECT 
    'problem_users_detail' as report_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    u.created_at,
    au.raw_user_meta_data->>'coinw_uid' as original_coinw_meta,
    au.raw_user_meta_data->>'referrer_user_id' as original_referrer_meta
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NULL
ORDER BY u.created_at DESC;
