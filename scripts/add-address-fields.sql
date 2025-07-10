-- プロフィール用アドレスフィールドを追加

-- 1. usersテーブルにアドレスフィールドを追加
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS reward_address_bep20 TEXT,
ADD COLUMN IF NOT EXISTS nft_receive_address TEXT;

-- 2. 既存データの確認
SELECT 
    'Current users table structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('reward_address_bep20', 'nft_receive_address', 'user_id', 'email')
ORDER BY column_name;

-- 3. テストデータで確認
SELECT 
    'Sample user data' as info,
    user_id,
    email,
    reward_address_bep20,
    nft_receive_address
FROM users 
WHERE user_id = '7A9637';