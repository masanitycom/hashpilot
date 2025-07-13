-- 存在するテーブルの確認とクリーンアップ
-- withdrawal_requestsテーブルの存在確認から開始

-- ========================================
-- 1. 存在するテーブル一覧を確認
-- ========================================
SELECT 
    table_name,
    table_type,
    CASE 
        WHEN table_name LIKE '%withdrawal%' THEN '💰 出金関連'
        WHEN table_name LIKE '%profit%' THEN '📊 利益関連'
        WHEN table_name LIKE '%cycle%' THEN '🔄 サイクル関連'
        WHEN table_name LIKE '%yield%' THEN '📈 日利関連'
        WHEN table_name LIKE '%purchase%' THEN '🛒 購入関連'
        ELSE '📋 その他'
    END as category
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE'
ORDER BY category, table_name;

-- ========================================
-- 2. 出金関連の正しいテーブル名を確認
-- ========================================
SELECT 
    table_name
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name LIKE '%withdrawal%'
    OR table_name LIKE '%buyback%'
ORDER BY table_name;

-- ========================================
-- 3. 利益・サイクル関連テーブルの現在のデータ確認
-- ========================================

-- affiliate_cycleテーブルの現在の状況
SELECT 
    'affiliate_cycle' as table_name,
    COUNT(*) as total_users,
    SUM(COALESCE(available_usdt, 0)) as total_available_usdt,
    SUM(COALESCE(cum_usdt, 0)) as total_cum_usdt,
    MAX(COALESCE(available_usdt, 0)) as max_available_usdt,
    COUNT(CASE WHEN COALESCE(available_usdt, 0) > 0 THEN 1 END) as users_with_balance
FROM affiliate_cycle;

-- user_daily_profitテーブルの現在の状況
SELECT 
    'user_daily_profit' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT date) as unique_dates,
    SUM(COALESCE(daily_profit, 0)) as total_profit,
    MAX(date) as latest_date,
    MIN(date) as earliest_date
FROM user_daily_profit;

-- daily_yield_logテーブルの現在の状況
SELECT 
    'daily_yield_log' as table_name,
    COUNT(*) as total_records,
    MAX(date) as latest_date,
    MIN(date) as earliest_date,
    MAX(COALESCE(margin_rate, 0)) as max_margin_rate
FROM daily_yield_log;

-- ========================================
-- 4. ダッシュボードに影響する具体的なデータ
-- ========================================

-- 昨日の利益データ（ダッシュボードに表示される可能性）
SELECT 
    'yesterday_data' as data_type,
    COUNT(*) as record_count,
    SUM(COALESCE(daily_profit, 0)) as total_profit
FROM user_daily_profit 
WHERE date = CURRENT_DATE - INTERVAL '1 day';

-- 今月の利益データ
SELECT 
    'monthly_data' as data_type,
    COUNT(*) as record_count,
    SUM(COALESCE(daily_profit, 0)) as total_profit
FROM user_daily_profit 
WHERE date >= DATE_TRUNC('month', CURRENT_DATE);

-- available_usdtが残っているユーザー
SELECT 
    user_id,
    available_usdt,
    cum_usdt,
    total_nft_count,
    updated_at
FROM affiliate_cycle 
WHERE COALESCE(available_usdt, 0) > 0 OR COALESCE(cum_usdt, 0) > 0
ORDER BY available_usdt DESC
LIMIT 10;

-- ========================================
-- 5. 存在するテーブルのみでクリーンアップ実行
-- ========================================

-- A. user_daily_profit（日利データ）を完全削除
DELETE FROM user_daily_profit;

-- B. affiliate_cycleの利益関連データをリセット
UPDATE affiliate_cycle SET
    cum_usdt = 0,
    available_usdt = 0,
    cycle_number = 1,
    cycle_start_date = NULL,
    updated_at = NOW()
WHERE cum_usdt != 0 OR available_usdt != 0;

-- C. daily_yield_log（日利設定）を完全削除
DELETE FROM daily_yield_log;

-- D. 自動購入のpurchasesレコードを削除（存在する場合）
DELETE FROM purchases WHERE is_auto_purchase = true;

-- ========================================
-- 6. クリーンアップ後の確認
-- ========================================

-- 全テーブルの状態確認
SELECT 
    'AFTER_CLEANUP' as phase,
    'affiliate_cycle' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(available_usdt, 0)) as total_available,
    SUM(COALESCE(cum_usdt, 0)) as total_cum,
    MAX(COALESCE(available_usdt, 0)) as max_available
FROM affiliate_cycle
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'user_daily_profit' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(daily_profit, 0)) as total_profit,
    0 as zero_col1,
    0 as zero_col2
FROM user_daily_profit
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'daily_yield_log' as table_name,
    COUNT(*) as total_records,
    0 as zero_col1,
    0 as zero_col2,
    0 as zero_col3
FROM daily_yield_log;

-- ========================================
-- 7. ダッシュボード表示確認
-- ========================================
SELECT 
    'DASHBOARD_CHECK' as check_type,
    
    -- 昨日の利益（ダッシュボードに表示される）
    (SELECT COUNT(*) FROM user_daily_profit 
     WHERE date = CURRENT_DATE - INTERVAL '1 day') as yesterday_records,
    
    -- 今月の利益
    (SELECT COUNT(*) FROM user_daily_profit 
     WHERE date >= DATE_TRUNC('month', CURRENT_DATE)) as monthly_records,
    
    -- 利用可能残高があるユーザー
    (SELECT COUNT(*) FROM affiliate_cycle 
     WHERE COALESCE(available_usdt, 0) > 0) as users_with_balance,
     
    -- 最大残高
    (SELECT COALESCE(MAX(available_usdt), 0) FROM affiliate_cycle) as max_balance;

-- ========================================
-- 8. 計算チェック（3段目まで）
-- ========================================

-- Level1-3のアフィリエイト報酬計算をテスト
WITH test_calculation AS (
    SELECT 
        1000 as base_amount,
        0.016 as yield_rate,
        30 as margin_rate,
        -- 計算段階1: マージン後利率
        0.016 * (1 - 30.0/100) as after_margin,
        -- 計算段階2: ユーザー受取率 (60%)
        0.016 * (1 - 30.0/100) * 0.6 as user_rate,
        -- 計算段階3: アフィリエイト配分 (30%)
        0.016 * (1 - 30.0/100) * 0.3 as affiliate_rate
)
SELECT 
    'CALCULATION_TEST' as test_type,
    base_amount,
    yield_rate,
    margin_rate,
    after_margin as step1_after_margin,
    user_rate as step2_user_rate,
    affiliate_rate as step3_affiliate_rate,
    -- 実際の配布額
    base_amount * user_rate as user_profit,
    base_amount * affiliate_rate as affiliate_pool,
    -- Level別配分
    (base_amount * affiliate_rate) * 0.20 as level1_20pct,
    (base_amount * affiliate_rate) * 0.10 as level2_10pct,
    (base_amount * affiliate_rate) * 0.05 as level3_5pct
FROM test_calculation;

-- 完了ログ
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'table_verification_cleanup',
    NULL,
    'テーブル確認と存在するテーブルのみでクリーンアップ完了',
    jsonb_build_object(
        'action', '存在するテーブルのみでデータリセット',
        'note', 'withdrawal_requestsテーブルは存在しないため除外'
    ),
    NOW()
);