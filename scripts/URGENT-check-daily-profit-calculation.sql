-- ========================================
-- 日利計算の問題を診断
-- ========================================

-- 1. process_daily_yield_with_cycles関数の計算ロジックを確認
SELECT
    '日利計算関数のチェック' as section,
    routine_definition LIKE '%nft_value%' as uses_nft_value,
    routine_definition LIKE '%1100%' as uses_hardcoded_1100,
    routine_definition LIKE '%base_amount%' as uses_base_amount
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 2. NFTの実際のnft_value分布を確認
SELECT
    'NFT価格分布' as section,
    nft_type,
    nft_value,
    COUNT(*) as count
FROM nft_master
WHERE buyback_date IS NULL
GROUP BY nft_type, nft_value
ORDER BY nft_type, nft_value;

-- 3. 10/2の日利計算結果をチェック
SELECT
    '10/2の日利計算' as section,
    nm.user_id,
    nm.nft_type,
    nm.nft_value as actual_nft_value,
    ndp.daily_profit as calculated_profit,
    ndp.yield_rate,
    -- 正しい計算（nft_valueベース）
    nm.nft_value * ndp.yield_rate * 0.7 * 0.6 as should_be_profit,
    -- 間違った計算（1100固定）
    1100 * ndp.yield_rate * 0.7 * 0.6 as wrong_calculation,
    CASE
        WHEN ABS(ndp.daily_profit - (nm.nft_value * ndp.yield_rate * 0.7 * 0.6)) < 0.01 THEN '✅ 正しい'
        WHEN ABS(ndp.daily_profit - (1100 * ndp.yield_rate * 0.7 * 0.6)) < 0.01 THEN '❌ 1100固定で計算'
        ELSE '⚠️ その他の問題'
    END as diagnosis
FROM nft_master nm
INNER JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE ndp.date = '2025-10-02'
ORDER BY nm.user_id, nm.nft_type
LIMIT 20;

-- 4. affiliate_cycleの枚数が正しいか確認
SELECT
    'affiliate_cycleの枚数確認' as section,
    ac.user_id,
    ac.total_nft_count as cycle_nft_count,
    ac.manual_nft_count,
    ac.auto_nft_count,
    COUNT(nm.id) as actual_nft_count,
    CASE
        WHEN ac.total_nft_count = COUNT(nm.id) THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.buyback_date IS NULL
GROUP BY ac.user_id, ac.total_nft_count, ac.manual_nft_count, ac.auto_nft_count
HAVING ac.total_nft_count != COUNT(nm.id) OR ac.auto_nft_count > 0
ORDER BY ac.auto_nft_count DESC
LIMIT 10;

-- 5. 自動NFT付与後のユーザーの状況
SELECT
    '自動NFT付与後のユーザー' as section,
    u.user_id,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.total_nft_count,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'manual') as actual_manual,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'auto') as actual_auto,
    COUNT(nm.id) as actual_total
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE ac.auto_nft_count > 0
GROUP BY u.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count
ORDER BY ac.auto_nft_count DESC
LIMIT 10;
