-- 🔍 全ユーザーの利益計算調査・ダッシュボード10倍問題の特定
-- 2025年1月16日

-- 1. 最新5日間の日利設定確認
SELECT 
    '=== 最新5日間の日利設定 ===' as investigation,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log 
WHERE date >= CURRENT_DATE - INTERVAL '5 days'
ORDER BY date DESC;

-- 2. 全ユーザーの最新5日間利益記録
SELECT 
    '=== 全ユーザー利益記録 ===' as investigation,
    udp.date,
    udp.user_id,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    ac.total_nft_count,
    -- 期待される利益計算
    (ac.total_nft_count * 1000 * udp.user_rate) as expected_profit,
    -- 実際の利益との差
    (udp.daily_profit - (ac.total_nft_count * 1000 * udp.user_rate)) as profit_difference,
    -- 差の比率
    CASE 
        WHEN (ac.total_nft_count * 1000 * udp.user_rate) != 0 THEN
            ROUND((udp.daily_profit / (ac.total_nft_count * 1000 * udp.user_rate) - 1) * 100, 2)
        ELSE 0
    END as difference_percentage
FROM user_daily_profit udp
JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
WHERE udp.date >= CURRENT_DATE - INTERVAL '5 days'
ORDER BY udp.date DESC, udp.daily_profit DESC;

-- 3. 同じ日・同じNFT数での利益比較
SELECT 
    '=== 同じ条件での利益一貫性確認 ===' as investigation,
    udp.date,
    ac.total_nft_count as nft_count,
    COUNT(*) as user_count,
    MIN(udp.daily_profit) as min_profit,
    MAX(udp.daily_profit) as max_profit,
    AVG(udp.daily_profit) as avg_profit,
    STDDEV(udp.daily_profit) as profit_stddev,
    -- 最大と最小の差
    (MAX(udp.daily_profit) - MIN(udp.daily_profit)) as profit_range,
    -- 異常な差があるかチェック
    CASE 
        WHEN STDDEV(udp.daily_profit) > 0.01 THEN '🚨 利益にばらつきあり'
        ELSE '正常'
    END as consistency_check
FROM user_daily_profit udp
JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
WHERE udp.date >= CURRENT_DATE - INTERVAL '5 days'
GROUP BY udp.date, ac.total_nft_count
HAVING COUNT(*) > 1  -- 同じ条件のユーザーが複数いる場合のみ
ORDER BY udp.date DESC, ac.total_nft_count;

-- 4. 異常に高い/低い利益のユーザー特定
SELECT 
    '=== 異常な利益のユーザー特定 ===' as investigation,
    udp.date,
    udp.user_id,
    u.email,
    ac.total_nft_count,
    udp.daily_profit,
    udp.user_rate,
    -- 期待される利益
    (ac.total_nft_count * 1000 * udp.user_rate) as expected_profit,
    -- 異常度（倍率）
    CASE 
        WHEN (ac.total_nft_count * 1000 * udp.user_rate) != 0 THEN
            ROUND(udp.daily_profit / (ac.total_nft_count * 1000 * udp.user_rate), 2)
        ELSE 0
    END as profit_multiplier,
    -- 問題分類
    CASE 
        WHEN ABS(udp.daily_profit - (ac.total_nft_count * 1000 * udp.user_rate)) < 0.01 THEN '正常'
        WHEN udp.daily_profit > (ac.total_nft_count * 1000 * udp.user_rate) * 2 THEN '🚨 利益2倍以上'
        WHEN udp.daily_profit < (ac.total_nft_count * 1000 * udp.user_rate) * 0.5 THEN '🚨 利益半分以下'
        ELSE '🔴 計算不一致'
    END as issue_type
FROM user_daily_profit udp
JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
JOIN users u ON udp.user_id = u.user_id
WHERE udp.date >= CURRENT_DATE - INTERVAL '5 days'
AND ABS(udp.daily_profit - (ac.total_nft_count * 1000 * udp.user_rate)) > 0.01
ORDER BY 
    CASE 
        WHEN (ac.total_nft_count * 1000 * udp.user_rate) != 0 THEN
            ABS(udp.daily_profit / (ac.total_nft_count * 1000 * udp.user_rate) - 1)
        ELSE 0
    END DESC;

-- 5. NFTあたりの利益統計
SELECT 
    '=== NFTあたり利益統計 ===' as investigation,
    udp.date,
    udp.user_rate as set_user_rate,
    COUNT(*) as total_users,
    -- NFTあたりの実際の利益
    ROUND(AVG(udp.daily_profit / ac.total_nft_count), 4) as avg_profit_per_nft,
    ROUND(MIN(udp.daily_profit / ac.total_nft_count), 4) as min_profit_per_nft,
    ROUND(MAX(udp.daily_profit / ac.total_nft_count), 4) as max_profit_per_nft,
    -- 期待される利益（1NFT = 1000ドル × 利率）
    ROUND(1000 * udp.user_rate, 4) as expected_profit_per_nft,
    -- 期待値との差
    ROUND(AVG(udp.daily_profit / ac.total_nft_count) - (1000 * udp.user_rate), 4) as difference_from_expected
FROM user_daily_profit udp
JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
WHERE udp.date >= CURRENT_DATE - INTERVAL '5 days'
AND ac.total_nft_count > 0
GROUP BY udp.date, udp.user_rate
ORDER BY udp.date DESC;

-- 6. ダッシュボード表示の原因調査
-- base_amountが正しく設定されているかチェック
SELECT 
    '=== base_amount設定確認 ===' as investigation,
    udp.date,
    udp.user_id,
    ac.total_nft_count,
    udp.base_amount,
    -- 期待されるbase_amount
    (ac.total_nft_count * 1000) as expected_base_amount,
    -- base_amountの差
    (udp.base_amount - (ac.total_nft_count * 1000)) as base_amount_difference,
    udp.daily_profit,
    udp.user_rate
FROM user_daily_profit udp
JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
WHERE udp.date >= CURRENT_DATE - INTERVAL '5 days'
AND udp.base_amount != (ac.total_nft_count * 1000)
ORDER BY ABS(udp.base_amount - (ac.total_nft_count * 1000)) DESC;

-- 7. 利益計算式の一貫性確認
SELECT 
    '=== 利益計算式の一貫性 ===' as investigation,
    udp.date,
    COUNT(*) as total_records,
    -- 正しい計算式のレコード数
    COUNT(CASE 
        WHEN ABS(udp.daily_profit - (udp.base_amount * udp.user_rate)) < 0.01 THEN 1 
    END) as correct_calculation_count,
    -- 間違った計算式のレコード数
    COUNT(CASE 
        WHEN ABS(udp.daily_profit - (udp.base_amount * udp.user_rate)) >= 0.01 THEN 1 
    END) as incorrect_calculation_count,
    -- 正確性の割合
    ROUND(
        COUNT(CASE WHEN ABS(udp.daily_profit - (udp.base_amount * udp.user_rate)) < 0.01 THEN 1 END) * 100.0 / COUNT(*), 2
    ) as accuracy_percentage
FROM user_daily_profit udp
WHERE udp.date >= CURRENT_DATE - INTERVAL '5 days'
GROUP BY udp.date
ORDER BY udp.date DESC;