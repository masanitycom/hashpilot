-- 緊急調査: 利益計算が狂った原因を特定

-- ========================================
-- 1. 7A9637ユーザーの実際のデータを確認
-- ========================================

-- 今日の日利データ（実際の配布額）
SELECT 
    'user_7A9637_daily_profit' as data_type,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at,
    -- 手動再計算
    base_amount * user_rate as recalculated_profit,
    daily_profit - (base_amount * user_rate) as calculation_error
FROM user_daily_profit 
WHERE user_id = '7A9637'
    AND date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC;

-- 7A9637のaffiliate_cycleデータ
SELECT 
    'user_7A9637_cycle' as data_type,
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    next_action,
    updated_at
FROM affiliate_cycle 
WHERE user_id = '7A9637';

-- ========================================
-- 2. 今日設定した日利の設定値を確認
-- ========================================

-- 今日の日利設定
SELECT 
    'todays_yield_settings' as data_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at,
    -- 手動計算
    yield_rate * (1 - margin_rate/100) as after_margin,
    yield_rate * (1 - margin_rate/100) * 0.6 as calculated_user_rate,
    yield_rate * (1 - margin_rate/100) * 0.3 as calculated_affiliate_rate
FROM daily_yield_log 
WHERE date = CURRENT_DATE
ORDER BY created_at DESC;

-- ========================================
-- 3. 全ユーザーの今日の利益配布を確認
-- ========================================

-- 今日処理された全ユーザー
SELECT 
    'all_users_today' as data_type,
    user_id,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    base_amount * user_rate as should_be_profit,
    daily_profit - (base_amount * user_rate) as error_amount,
    CASE 
        WHEN ABS(daily_profit - (base_amount * user_rate)) < 0.01 THEN '✅ 正確'
        ELSE '❌ 計算エラー'
    END as calculation_status
FROM user_daily_profit 
WHERE date = CURRENT_DATE
ORDER BY ABS(daily_profit - (base_amount * user_rate)) DESC;

-- ========================================
-- 4. アフィリエイト報酬の確認
-- ========================================

-- 紹介関係の確認
SELECT 
    'referral_structure' as data_type,
    u1.user_id as user,
    u1.email as user_email,
    u2.user_id as referrer,
    u2.email as referrer_email,
    ac1.total_nft_count as user_nft,
    ac2.total_nft_count as referrer_nft
FROM users u1
LEFT JOIN users u2 ON u1.referrer_user_id = u2.user_id
LEFT JOIN affiliate_cycle ac1 ON u1.user_id = ac1.user_id
LEFT JOIN affiliate_cycle ac2 ON u2.user_id = ac2.user_id
WHERE u1.user_id = '7A9637' OR u2.user_id = '7A9637'
ORDER BY u1.user_id;

-- ========================================
-- 5. 期待値との比較
-- ========================================

-- 正しい計算の期待値
WITH expected_calculation AS (
    SELECT 
        '7A9637' as user_id,
        1 as nft_count,
        1000 as base_amount,
        0.021 as yield_rate,  -- 2.1%と仮定
        0.30 as margin_rate,  -- 30%
        0.021 * (1 - 0.30) * 0.6 as expected_user_rate,
        1000 * (0.021 * (1 - 0.30) * 0.6) as expected_daily_profit
)
SELECT 
    'expected_vs_actual' as comparison_type,
    ec.user_id,
    ec.expected_daily_profit,
    udp.daily_profit as actual_daily_profit,
    ec.expected_daily_profit - udp.daily_profit as difference,
    ec.expected_user_rate,
    udp.user_rate as actual_user_rate
FROM expected_calculation ec
LEFT JOIN user_daily_profit udp ON ec.user_id = udp.user_id 
    AND udp.date = CURRENT_DATE;

-- ========================================
-- 6. 日利処理関数のユーザー受取率計算を確認
-- ========================================

-- 現在の日利設定から手動計算
SELECT 
    'manual_rate_calculation' as calc_type,
    dyl.yield_rate,
    dyl.margin_rate,
    dyl.user_rate as stored_user_rate,
    -- 手動計算
    dyl.yield_rate * (1 - dyl.margin_rate/100) as step1_after_margin,
    dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.6 as step2_user_rate,
    dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.3 as step3_affiliate_rate,
    -- 比較
    CASE 
        WHEN ABS(dyl.user_rate - (dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.6)) < 0.000001 
        THEN '✅ 正確'
        ELSE '❌ エラー'
    END as rate_calculation_status
FROM daily_yield_log dyl
WHERE dyl.date = CURRENT_DATE
ORDER BY created_at DESC
LIMIT 1;

-- ========================================
-- 7. 結論
-- ========================================
SELECT 
    '🚨 緊急調査結果 🚨' as investigation,
    '計算エラーの原因を特定中' as status,
    '上記のデータを確認してください' as action;