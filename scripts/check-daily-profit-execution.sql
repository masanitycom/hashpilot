-- ========================================
-- 🚨 日利処理実行状況の緊急確認
-- user_daily_profitテーブルが空の原因調査
-- ========================================

-- STEP 1: user_daily_profitテーブルの詳細確認
SELECT 
    '=== 🔍 user_daily_profit確認 ===' as check_status,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM user_daily_profit;

-- STEP 2: 最近の日利設定確認
SELECT 
    '=== 📈 直近の日利設定 ===' as yield_status,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end
FROM daily_yield_log
ORDER BY date DESC
LIMIT 7;

-- STEP 3: 運用開始済みユーザー確認
SELECT 
    '=== 👥 運用開始済みユーザー ===' as user_status,
    COUNT(*) as total_users,
    COUNT(CASE WHEN has_approved_nft = true THEN 1 END) as approved_users,
    SUM(total_purchases) as total_investment
FROM users;

-- STEP 4: affiliate_cycleの利益記録確認
SELECT 
    '=== 🔄 サイクル利益データ ===' as cycle_status,
    user_id,
    total_nft_count,
    cum_usdt,
    available_usdt,
    CASE 
        WHEN cum_usdt > 0 THEN 'Has Profit'
        ELSE 'No Profit'
    END as profit_status
FROM affiliate_cycle
WHERE total_nft_count > 0
ORDER BY cum_usdt DESC
LIMIT 10;

-- STEP 5: 7A9637の詳細確認
SELECT 
    '=== 🎯 User 7A9637 詳細 ===' as target_user,
    u.user_id,
    u.total_purchases,
    u.has_approved_nft,
    u.created_at as user_created,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = '7A9637';

-- STEP 6: 手動計算でuser_daily_profitにデータを作成
-- 7/16の日利設定を使用してUser 7A9637の利益を計算

WITH yesterday_yield AS (
    SELECT 
        date,
        yield_rate,
        margin_rate,
        user_rate
    FROM daily_yield_log
    WHERE date = '2025-07-16'
),
user_nft AS (
    SELECT 
        user_id,
        total_nft_count
    FROM affiliate_cycle
    WHERE user_id = '7A9637'
)
SELECT 
    '=== 💰 手動利益計算 ===' as manual_calc,
    un.user_id,
    un.total_nft_count,
    (un.total_nft_count * 1000) as operation_amount,
    yy.user_rate,
    (un.total_nft_count * 1000 * yy.user_rate) as calculated_profit,
    yy.date as target_date
FROM user_nft un
CROSS JOIN yesterday_yield yy;

-- STEP 7: 緊急データ挿入（テスト用）
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase
)
SELECT 
    ac.user_id,
    '2025-07-16' as date,
    (ac.total_nft_count * 1000 * 0.00072) as daily_profit,
    0.0012 as yield_rate,
    0.00072 as user_rate,
    (ac.total_nft_count * 1000) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase;

-- STEP 8: 挿入後確認
SELECT 
    '=== ✅ 挿入後確認 ===' as insert_check,
    COUNT(*) as total_records,
    SUM(daily_profit) as total_daily_profit
FROM user_daily_profit
WHERE date = '2025-07-16';

-- STEP 9: User 7A9637の結果確認
SELECT 
    '=== 🎯 7A9637 最終確認 ===' as final_check,
    user_id,
    date,
    daily_profit,
    base_amount,
    phase
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-07-16';