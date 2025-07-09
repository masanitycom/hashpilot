-- usersテーブルに新しいアドレスフィールドを追加

-- 報酬受け取りアドレス（USDT BEP20）カラムを追加
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS reward_address_bep20 text;

-- NFT受取アドレスカラムを追加
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS nft_receive_address text;

-- インデックスを追加（検索性能向上のため）
CREATE INDEX IF NOT EXISTS idx_users_reward_address ON users(reward_address_bep20);
CREATE INDEX IF NOT EXISTS idx_users_nft_address ON users(nft_receive_address);

-- 既存のユーザーデータを確認
SELECT 
    user_id,
    email,
    coinw_uid,
    reward_address_bep20,
    nft_receive_address,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- テーブル構造を確認
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;
