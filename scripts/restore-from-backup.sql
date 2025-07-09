-- バックアップからの復元スクリプト（緊急時用）

-- 注意: このスクリプトは緊急時のみ使用してください

-- 1. 現在のテーブルをバックアップ（復元前）
CREATE TABLE IF NOT EXISTS pre_restore_users_20250706 AS
SELECT * FROM users;

-- 2. usersテーブルの復元（コメントアウト状態）
/*
TRUNCATE TABLE users;
INSERT INTO users SELECT * FROM backup_users_20250706;
*/

-- 3. 復元確認用クエリ
/*
SELECT 
    'restore_verification' as check_type,
    COUNT(*) as restored_users,
    COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) as users_with_coinw,
    COUNT(CASE WHEN referrer_user_id IS NOT NULL THEN 1 END) as users_with_referrer
FROM users;
*/

-- 4. 特定ユーザーの復元確認
/*
SELECT 
    'specific_users_check' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637')
ORDER BY created_at DESC;
*/
