-- ========================================
-- nft_masterテーブルの構造確認
-- ========================================

-- 1. テーブル構造を確認
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'nft_master'
ORDER BY ordinal_position;

-- 2. サンプルデータを表示
SELECT *
FROM nft_master
LIMIT 5;

-- 3. ユーザー7A9637のデータ
SELECT *
FROM nft_master
WHERE user_id = '7A9637';
