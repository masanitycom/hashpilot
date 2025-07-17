-- 昨日の日利表示問題の確認

-- 1. 7/16の実際の日利設定
SELECT 
    '=== 7/16の日利設定 ===' as check_status,
    date,
    yield_rate * 100 as yield_rate_percent,
    user_rate * 100 as user_rate_percent,
    margin_rate * 100 as margin_rate_percent
FROM daily_yield_log
WHERE date = '2025-07-16';

-- 2. 7A9637の7/16データ確認
SELECT 
    '=== 7A9637の実際のデータ ===' as user_data,
    user_id,
    date,
    daily_profit,
    yield_rate * 100 as yield_rate_percent,
    user_rate * 100 as user_rate_percent,
    base_amount
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-07-16';

-- 3. 計算確認
-- yield_rate: 0.12% (0.0012)
-- margin_rate: 30% (0.30)
-- 正しい計算: 0.12% × (1 - 30%) × 60% = 0.0504%
-- しかし実際は: 0.072% になっている

SELECT 
    '=== 計算の検証 ===' as calculation_check,
    0.12 as yield_rate_percent,
    30 as margin_rate_percent,
    0.12 * (1 - 0.30) * 0.6 as correct_user_rate_percent,
    0.072 as actual_user_rate_percent;