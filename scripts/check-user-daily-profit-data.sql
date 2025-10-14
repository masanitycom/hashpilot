-- ========================================
-- user_daily_profitテーブルのデータ確認
-- ========================================

-- 1. user_daily_profitのレコード数
SELECT
    'user_daily_profit' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT date) as unique_dates,
    MAX(date) as latest_date,
    MIN(date) as earliest_date
FROM user_daily_profit;

-- 2. nft_daily_profitのレコード数（比較用）
SELECT
    'nft_daily_profit' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT date) as unique_dates,
    MAX(date) as latest_date,
    MIN(date) as earliest_date
FROM nft_daily_profit;

-- 3. user_daily_profitの最新データ（サンプル）
SELECT
    date,
    user_id,
    daily_profit,
    yield_rate,
    created_at
FROM user_daily_profit
ORDER BY date DESC, created_at DESC
LIMIT 10;

-- 4. nft_daily_profitの最新データ（サンプル）
SELECT
    date,
    user_id,
    nft_id,
    daily_profit,
    yield_rate,
    created_at
FROM nft_daily_profit
ORDER BY date DESC, created_at DESC
LIMIT 10;

-- 5. user_daily_profitとnft_daily_profitの整合性チェック
SELECT
    ndp.date,
    ndp.user_id,
    SUM(ndp.daily_profit) as nft_total_profit,
    udp.daily_profit as user_daily_profit,
    CASE
        WHEN udp.daily_profit IS NULL THEN '❌ user_daily_profitに存在しない'
        WHEN ABS(SUM(ndp.daily_profit) - udp.daily_profit) < 0.001 THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as status
FROM nft_daily_profit ndp
LEFT JOIN user_daily_profit udp ON ndp.user_id = udp.user_id AND ndp.date = udp.date
GROUP BY ndp.date, ndp.user_id, udp.daily_profit
ORDER BY ndp.date DESC, ndp.user_id
LIMIT 20;
