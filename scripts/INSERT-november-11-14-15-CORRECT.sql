-- ========================================
-- 11/11、11/14、11/15の正しいデータを挿入
-- ========================================
--
-- 設定された日利率からユーザー受取率を計算
-- マージン0%: user_rate = yield_rate × 0.6
-- ========================================

-- 2025-11-11: yield_rate 0.586% → user_rate 0.352%
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
    0.586,
    0.00,
    0.3516,
    false,
    '2025-11-11 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-11'
);

-- 2025-11-14: yield_rate 0.400% → user_rate 0.240%
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
    0.400,
    0.00,
    0.240,
    false,
    '2025-11-14 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-14'
);

-- 2025-11-15: yield_rate 0.535% → user_rate 0.321%
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
    0.535,
    0.00,
    0.321,
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
WHERE date >= '2025-11-11' AND date <= '2025-11-15'
ORDER BY date;
