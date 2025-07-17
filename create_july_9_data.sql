-- ========================================
-- 7/9の日利データを手動作成
-- ========================================

-- STEP 1: daily_yield_logに7/9のデータを作成
-- 例: 日利0.15%、マージン30%と仮定
INSERT INTO daily_yield_log (
    date, 
    yield_rate, 
    margin_rate, 
    user_rate, 
    is_month_end, 
    created_at
)
VALUES (
    '2025-07-09',
    0.0015,  -- 0.15%
    0.30,    -- 30%
    0.0015 * (1 - 0.30) * 0.6,  -- = 0.00063 (0.063%)
    false,
    NOW()
)
ON CONFLICT (date) DO UPDATE SET
    yield_rate = EXCLUDED.yield_rate,
    margin_rate = EXCLUDED.margin_rate,
    user_rate = EXCLUDED.user_rate,
    created_at = NOW();

-- STEP 2: 作成されたデータの確認
SELECT 
    '=== 作成後の7/9設定確認 ===' as status,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent
FROM daily_yield_log
WHERE date = '2025-07-09';

-- STEP 3: user_daily_profitに7/9のデータを作成
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase,
    created_at
)
SELECT 
    ac.user_id,
    '2025-07-09' as date,
    (ac.total_nft_count * 1100 * yl.user_rate) as daily_profit,
    yl.yield_rate,
    yl.user_rate,
    (ac.total_nft_count * 1100) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase,
    '2025-07-09 16:00:00+00' as created_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
CROSS JOIN (
    SELECT yield_rate, user_rate 
    FROM daily_yield_log 
    WHERE date = '2025-07-09'
    LIMIT 1
) yl
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase;

-- STEP 4: 作成結果の確認
SELECT 
    '=== 7/9の利益データ作成結果 ===' as result_check,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit
FROM user_daily_profit
WHERE date = '2025-07-09';

-- STEP 5: 特定ユーザーの7/9データ確認
SELECT 
    '=== 7A9637の7/9データ ===' as user_check,
    user_id,
    date,
    daily_profit,
    user_rate * 100 as user_rate_percent,
    base_amount
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-07-09';

-- STEP 6: 全期間のデータ確認
SELECT 
    '=== 全期間の日利設定（日付順）===' as all_data,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent
FROM daily_yield_log
ORDER BY date;