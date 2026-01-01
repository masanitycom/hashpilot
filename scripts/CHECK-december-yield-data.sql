-- ========================================
-- 12月の日利データ確認スクリプト
-- ========================================

-- 1. V2テーブル（12月）のデータ確認
SELECT '=== 1. daily_yield_log_v2（V2システム）のデータ ===' as section;

SELECT
    id,
    date,
    daily_pnl,
    total_nft_count,
    profit_per_nft,
    fee_rate,
    created_at
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 50;

-- 2. V1テーブル（11月）のデータ確認
SELECT '=== 2. daily_yield_log（V1システム）の最新データ ===' as section;

SELECT
    id,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    total_users,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

-- 3. 月別レコード数
SELECT '=== 3. 月別レコード数 ===' as section;

SELECT
    'V1' as system,
    EXTRACT(YEAR FROM date) as year,
    EXTRACT(MONTH FROM date) as month,
    COUNT(*) as record_count
FROM daily_yield_log
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
UNION ALL
SELECT
    'V2' as system,
    EXTRACT(YEAR FROM date) as year,
    EXTRACT(MONTH FROM date) as month,
    COUNT(*) as record_count
FROM daily_yield_log_v2
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
ORDER BY system, year DESC, month DESC;

-- 4. テーブルが存在するか確認
SELECT '=== 4. テーブル存在確認 ===' as section;

SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('daily_yield_log', 'daily_yield_log_v2')
ORDER BY table_name;

-- 5. nft_daily_profitの12月データ
SELECT '=== 5. nft_daily_profit（12月）のデータ数 ===' as section;

SELECT
    date,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit
FROM nft_daily_profit
WHERE date >= '2025-12-01'
GROUP BY date
ORDER BY date DESC
LIMIT 31;

-- 6. user_daily_profitの12月データ
SELECT '=== 6. user_daily_profit（12月）のデータ数 ===' as section;

SELECT
    date,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-12-01'
GROUP BY date
ORDER BY date DESC
LIMIT 31;
