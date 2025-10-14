-- ========================================
-- 利益テーブルの確認
-- ========================================

-- 1. user_daily_profitテーブルの存在確認
SELECT
    'user_daily_profit テーブル' as table_name,
    COUNT(*) as record_count,
    MAX(date) as latest_date,
    MIN(date) as earliest_date
FROM user_daily_profit;

-- 2. nft_daily_profitテーブルの確認
SELECT
    'nft_daily_profit テーブル' as table_name,
    COUNT(*) as record_count,
    MAX(date) as latest_date,
    MIN(date) as earliest_date
FROM nft_daily_profit;

-- 3. nft_daily_profitからuser_daily_profitへの集計が必要か確認
SELECT
    user_id,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
GROUP BY user_id, date
ORDER BY date DESC, user_id
LIMIT 20;

-- 4. user_daily_profitビューまたはテーブルの定義を確認
SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_name IN ('user_daily_profit', 'nft_daily_profit');
