-- ========================================
-- 12月運用されていない3ユーザーの調査（続き）
-- ========================================

-- nft_daily_profitテーブルの構造確認
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'nft_daily_profit'
ORDER BY ordinal_position;
