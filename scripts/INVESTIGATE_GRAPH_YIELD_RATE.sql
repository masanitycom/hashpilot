-- 🔍 グラフの日利率問題を調査
-- 2025年7月17日

-- 1. 日利設定データ（管理者が設定した実際の日利率）
SELECT 
    'admin_set_yield_rates' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end
FROM daily_yield_log
WHERE date >= '2025-07-01'
ORDER BY date DESC;

-- 2. 実際のユーザー利益データ（7A9637）
SELECT 
    'user_profit_data' as check_type,
    date,
    daily_profit,
    base_amount,
    yield_rate,
    user_rate,
    phase
FROM user_daily_profit
WHERE user_id = '7A9637'
AND date >= '2025-07-01'
ORDER BY date DESC;

-- 3. 日利率計算の検証
SELECT 
    'rate_calculation_verification' as check_type,
    udp.date,
    udp.daily_profit,
    udp.base_amount,
    udp.yield_rate as stored_yield_rate,
    udp.user_rate as stored_user_rate,
    dyl.yield_rate as admin_yield_rate,
    dyl.user_rate as admin_user_rate,
    -- 現在のグラフ計算方法
    CASE 
        WHEN udp.base_amount > 0 THEN udp.daily_profit / udp.base_amount
        ELSE 0
    END as graph_calculated_rate,
    -- 正しい計算方法
    dyl.user_rate as correct_rate_for_graph
FROM user_daily_profit udp
LEFT JOIN daily_yield_log dyl ON udp.date = dyl.date
WHERE udp.user_id = '7A9637'
AND udp.date >= '2025-07-01'
ORDER BY udp.date DESC;

-- 4. 日利設定とユーザー利益の整合性確認
SELECT 
    'consistency_check' as check_type,
    udp.date,
    udp.daily_profit,
    udp.base_amount,
    dyl.user_rate,
    -- 期待される利益 = base_amount × user_rate
    udp.base_amount * dyl.user_rate as expected_profit,
    -- 実際の利益との差
    udp.daily_profit - (udp.base_amount * dyl.user_rate) as profit_difference
FROM user_daily_profit udp
LEFT JOIN daily_yield_log dyl ON udp.date = dyl.date
WHERE udp.user_id = '7A9637'
AND udp.date >= '2025-07-01'
AND udp.base_amount > 0
ORDER BY udp.date DESC;