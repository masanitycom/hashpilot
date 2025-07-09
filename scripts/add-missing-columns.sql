-- usersテーブルの現在の構造を確認
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- 不足しているカラムを追加
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS has_approved_nft BOOLEAN DEFAULT FALSE;

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS first_nft_approved_at TIMESTAMP WITH TIME ZONE;

-- purchasesテーブルにも必要なカラムを追加
ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT FALSE;

ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS admin_approved_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS admin_approved_by TEXT;

ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS payment_proof_url TEXT;

ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS user_notes TEXT;

ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- payment_statusのデフォルト値を設定
ALTER TABLE purchases 
ALTER COLUMN payment_status SET DEFAULT 'pending';

-- 既存のユーザーで承認済み購入がある場合、has_approved_nftをtrueに設定
UPDATE users 
SET has_approved_nft = TRUE, first_nft_approved_at = NOW()
WHERE user_id IN (
    SELECT DISTINCT user_id 
    FROM purchases 
    WHERE payment_status = 'completed' OR nft_sent = TRUE
);

-- 購入データの表示用ビューを再作成
DROP VIEW IF EXISTS purchase_admin_view;

CREATE VIEW purchase_admin_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes,
    p.created_at,
    p.confirmed_at,
    p.completed_at,
    u.has_approved_nft
FROM purchases p
JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- テーブル構造を確認
SELECT 'users table columns:' as info;
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

SELECT 'purchases table columns:' as info;
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- 現在のデータ状況を確認
SELECT 'Current user status:' as info;
SELECT 
    user_id,
    email,
    has_approved_nft,
    first_nft_approved_at,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;

SELECT 'Current purchase status:' as info;
SELECT 
    id,
    user_id,
    amount_usd,
    payment_status,
    admin_approved,
    created_at
FROM purchases 
ORDER BY created_at DESC 
LIMIT 5;
