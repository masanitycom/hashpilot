-- 緊急：CoinW UIDの文字数制限を修正（ビュー依存問題を解決）

-- 1. 現在のテーブル構造を確認
SELECT 
    'current_coinw_uid_structure' as check_type,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'coinw_uid';

-- 2. purchasesテーブルの構造を確認
SELECT 
    'purchases_table_structure' as check_type,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'purchases'
ORDER BY ordinal_position;

-- 3. 依存するビューを一時的に削除
DROP VIEW IF EXISTS admin_purchases_view;

-- 4. CoinW UIDの文字数制限を拡張（6文字 → 20文字）
ALTER TABLE users 
ALTER COLUMN coinw_uid TYPE VARCHAR(20);

-- 5. 確認
SELECT 
    'updated_coinw_uid_structure' as check_type,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'coinw_uid';

-- 6. 現在のCoinW UIDの長さを確認
SELECT 
    'coinw_uid_length_check' as check_type,
    user_id,
    email,
    coinw_uid,
    LENGTH(coinw_uid) as uid_length
FROM users 
WHERE coinw_uid IS NOT NULL
ORDER BY LENGTH(coinw_uid) DESC;

SELECT 'coinw_uid_length_fixed' as status, NOW() as timestamp;
