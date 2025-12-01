-- ========================================
-- 11月1日～4日の正しい日利設定データを挿入
-- ========================================
--
-- ユーザー受取率から逆算:
-- user_rate = yield_rate × (1 - margin_rate) × 0.6
-- マージン0%の場合: user_rate = yield_rate
--
-- したがって:
-- yield_rate = user_rate (マージン0%の場合)
-- ========================================

-- まず既存データを削除（もしあれば）
DELETE FROM daily_yield_log WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-02';
DELETE FROM daily_yield_log WHERE date = '2025-11-03';
DELETE FROM daily_yield_log WHERE date = '2025-11-04';

-- 2025-11-01: -0.017%
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-01',
    -0.017,
    0.00,
    -0.017,
    false,
    '2025-11-01 12:00:00+09'
);

-- 2025-11-02: -0.004%
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-02',
    -0.004,
    0.00,
    -0.004,
    false,
    '2025-11-02 12:00:00+09'
);

-- 2025-11-03: -0.168%
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-03',
    -0.168,
    0.00,
    -0.168,
    false,
    '2025-11-03 12:00:00+09'
);

-- 2025-11-04: -0.695%
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
) VALUES (
    '2025-11-04',
    -0.695,
    0.00,
    -0.695,
    false,
    '2025-11-04 12:00:00+09'
);

-- 挿入結果を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-04'
ORDER BY date;
