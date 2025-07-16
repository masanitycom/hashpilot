-- 🔍 7/11データの表示問題調査
-- 2025年7月17日

-- 1. daily_yield_logテーブルの7/11データ確認
SELECT 
    '7/11_daily_yield_log' as check_type,
    id,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log 
WHERE date = '2025-07-11'
ORDER BY created_at DESC;

-- 2. user_daily_profitテーブルの7/11データ確認
SELECT 
    '7/11_user_daily_profit' as check_type,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit,
    MIN(created_at) as first_created,
    MAX(created_at) as last_created
FROM user_daily_profit 
WHERE date = '2025-07-11';

-- 3. 管理画面のクエリをシミュレート（最新10件）
SELECT 
    '管理画面クエリシミュレート' as check_type,
    id,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

-- 4. 7/11前後の日付確認
SELECT 
    '前後の日付確認' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log 
WHERE date BETWEEN '2025-07-10' AND '2025-07-12'
ORDER BY date DESC;

-- 5. 管理画面が参照する全データ確認
SELECT 
    '全daily_yield_log' as check_type,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(DISTINCT date) as unique_dates
FROM daily_yield_log;

-- 6. 特定の日付フォーマット確認
SELECT 
    '日付フォーマット確認' as check_type,
    date,
    date::text as date_text,
    EXTRACT(YEAR FROM date) as year,
    EXTRACT(MONTH FROM date) as month,
    EXTRACT(DAY FROM date) as day
FROM daily_yield_log 
WHERE date >= '2025-07-10'
ORDER BY date DESC;