-- ========================================
-- 11/11、11/14、11/15のデータを緊急復元
-- ========================================
--
-- user_daily_profitから逆算
-- マージン0%なので: yield_rate = user_rate / 0.6
-- ========================================

-- 11/11のNFT数確認（256ユーザー ≈ 256 NFT）
-- total_profit: $1,722.70
-- total_investment: 256 * 1000 = $256,000
-- user_rate: 1722.70 / 256000 * 100 = 0.6728%
-- yield_rate: 0.6728% / 0.6 = 1.1213%

INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-11',
    1.121289,
    0.00,
    0.672773,
    false,
    '2025-11-11 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-11'
);

-- 11/14のNFT数確認（256ユーザー ≈ 256 NFT）
-- total_profit: $1,176.00
-- total_investment: 256 * 1000 = $256,000
-- user_rate: 1176.00 / 256000 * 100 = 0.4594%
-- yield_rate: 0.4594% / 0.6 = 0.7656%

INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-14',
    0.765625,
    0.00,
    0.459375,
    false,
    '2025-11-14 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-14'
);

-- 11/15のNFT数確認（298ユーザー ≈ 298 NFT）
-- total_profit: $1,685.25
-- total_investment: 298 * 1000 = $298,000
-- user_rate: 1685.25 / 298000 * 100 = 0.5654%
-- yield_rate: 0.5654% / 0.6 = 0.9424%

INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-15',
    0.942365,
    0.00,
    0.565419,
    false,
    '2025-11-15 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-15'
);

-- 挿入結果を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    ROUND((yield_rate * (1 - margin_rate) * 0.6)::numeric, 6) as calculated_user_rate,
    CASE
        WHEN ABS(user_rate - (yield_rate * (1 - margin_rate) * 0.6)) < 0.001 THEN '✅'
        ELSE '❌'
    END as check
FROM daily_yield_log
WHERE date IN ('2025-11-11', '2025-11-14', '2025-11-15')
ORDER BY date;
