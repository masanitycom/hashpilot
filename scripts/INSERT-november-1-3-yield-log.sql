-- ========================================
-- 11月1日～3日の日利設定データをdaily_yield_logに挿入
-- ========================================

-- 2025-11-01
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-01',
    -0.054409,
    0.30,
    -0.022852,
    false,
    '2025-11-01 12:00:00+09'
);

-- 2025-11-02
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-02',
    -0.013602,
    0.30,
    -0.005713,
    false,
    '2025-11-02 12:00:00+09'
);

-- 2025-11-03
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-03',
    1.088189,
    0.30,
    0.457039,
    false,
    '2025-11-03 12:00:00+09'
);

-- 挿入結果を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-03'
ORDER BY date;
