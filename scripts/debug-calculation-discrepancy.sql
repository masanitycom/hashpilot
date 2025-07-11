-- 日利計算の不一致をデバッグ

-- 1. 実際のNFT数とbase_amountを確認
SELECT '=== NFT数とbase_amount確認 ===' as section;
SELECT 
    u.user_id,
    u.total_purchases,
    FLOOR(u.total_purchases / 1100) as calculated_nft_count,
    COALESCE(ac.total_nft_count, FLOOR(u.total_purchases / 1100)) as actual_nft_count,
    (COALESCE(ac.total_nft_count, FLOOR(u.total_purchases / 1100)) * 1000) as calculated_base_amount,
    udp.base_amount as recorded_base_amount,
    udp.personal_profit,
    udp.yield_rate,
    udp.user_rate
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-10'
WHERE u.total_purchases > 0
ORDER BY u.total_purchases DESC
LIMIT 10;

-- 2. 期待値 vs 実際の値の比較
SELECT '=== 期待値 vs 実際値 ===' as section;
WITH expected_calculation AS (
    SELECT 
        u.user_id,
        u.total_purchases,
        FLOOR(u.total_purchases / 1100) as nft_count,
        (FLOOR(u.total_purchases / 1100) * 1000) as base_amount,
        -- 期待される利率計算 (1.38% × (1-30%) × 0.6 = 0.5796%)
        (FLOOR(u.total_purchases / 1100) * 1000 * 0.005796) as expected_personal_profit
    FROM users u
    WHERE u.total_purchases > 0
)
SELECT 
    ec.user_id,
    ec.total_purchases,
    ec.nft_count,
    ec.base_amount,
    ec.expected_personal_profit,
    udp.personal_profit as actual_personal_profit,
    (udp.personal_profit - ec.expected_personal_profit) as difference,
    (udp.personal_profit / ec.expected_personal_profit) as ratio
FROM expected_calculation ec
LEFT JOIN user_daily_profit udp ON ec.user_id = udp.user_id AND udp.date = '2025-07-10'
WHERE ec.expected_personal_profit > 0
ORDER BY ec.total_purchases DESC
LIMIT 10;

-- 3. 日利設定の確認
SELECT '=== 日利設定確認 ===' as section;
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    -- 手動計算
    yield_rate * (1 - margin_rate/100) as calculated_after_margin,
    yield_rate * (1 - margin_rate/100) * 0.6 as calculated_user_rate
FROM daily_yield_log
WHERE date = '2025-07-10';

-- 4. affiliate_cycleテーブルの確認
SELECT '=== affiliate_cycleテーブル確認 ===' as section;
SELECT 
    user_id,
    total_nft_count,
    phase,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE user_id IN (
    SELECT user_id FROM users 
    WHERE total_purchases >= 2000 
    ORDER BY total_purchases DESC 
    LIMIT 5
);

-- 5. 計算式の検証
SELECT '=== 計算式検証 ===' as section;
SELECT 
    '2200ドル投資の期待値' as description,
    2200 as investment,
    FLOOR(2200/1100) as nft_count,
    (FLOOR(2200/1100) * 1000) as base_amount,
    1.38 as yield_rate_percent,
    (1.38 * (1-30.0/100)) as after_margin_percent,
    (1.38 * (1-30.0/100) * 0.6) as user_rate_percent,
    (FLOOR(2200/1100) * 1000 * (1.38 * (1-30.0/100) * 0.6) / 100) as expected_profit;

SELECT 
    '1100ドル投資の期待値' as description,
    1100 as investment,
    FLOOR(1100/1100) as nft_count,
    (FLOOR(1100/1100) * 1000) as base_amount,
    1.38 as yield_rate_percent,
    (1.38 * (1-30.0/100)) as after_margin_percent,
    (1.38 * (1-30.0/100) * 0.6) as user_rate_percent,
    (FLOOR(1100/1100) * 1000 * (1.38 * (1-30.0/100) * 0.6) / 100) as expected_profit;