-- ========================================
-- 実際の日利計算を検証
-- ========================================

-- 1. あなたのユーザーIDで確認（7A9637？）
SELECT
    'あなたのNFT情報' as section,
    nm.id,
    nm.nft_type,
    nm.nft_value,
    nm.nft_sequence
FROM nft_master nm
WHERE nm.user_id = '7A9637'
  AND nm.buyback_date IS NULL
ORDER BY nm.nft_sequence;

-- 2. 10/2の実際の計算結果
SELECT
    '10/2の日利計算結果' as section,
    nm.nft_type,
    nm.nft_value,
    ndp.daily_profit,
    ndp.yield_rate,
    -- 期待される計算: nft_value × yield_rate × 0.7 × 0.6
    nm.nft_value * ndp.yield_rate * 0.7 * 0.6 as expected_profit,
    -- 差分
    ndp.daily_profit - (nm.nft_value * ndp.yield_rate * 0.7 * 0.6) as difference,
    CASE
        WHEN ABS(ndp.daily_profit - (nm.nft_value * ndp.yield_rate * 0.7 * 0.6)) < 0.001 THEN '✅ 正しい'
        ELSE '❌ 間違い'
    END as status
FROM nft_master nm
INNER JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.user_id = '7A9637'
  AND ndp.date = '2025-10-02'
ORDER BY nm.nft_sequence;

-- 3. 10/1の計算結果も確認
SELECT
    '10/1の日利計算結果' as section,
    nm.nft_type,
    nm.nft_value,
    ndp.daily_profit,
    ndp.yield_rate,
    nm.nft_value * ndp.yield_rate * 0.7 * 0.6 as expected_profit,
    ndp.daily_profit - (nm.nft_value * ndp.yield_rate * 0.7 * 0.6) as difference,
    CASE
        WHEN ABS(ndp.daily_profit - (nm.nft_value * ndp.yield_rate * 0.7 * 0.6)) < 0.001 THEN '✅ 正しい'
        ELSE '❌ 間違い'
    END as status
FROM nft_master nm
INNER JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.user_id = '7A9637'
  AND ndp.date = '2025-10-01'
ORDER BY nm.nft_sequence;

-- 4. user_daily_profitの集計結果
SELECT
    'user_daily_profit（ビュー）' as section,
    date,
    daily_profit,
    yield_rate
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC;
