-- ========================================
-- 11月1日～4日の日利設定データを安全に挿入
-- ========================================
--
-- 既存データがある場合はスキップ（削除しない）
-- ========================================

-- STEP 1: 既存データを確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-04'
ORDER BY date;

-- STEP 2: 存在しない日付のみ挿入
-- 2025-11-01
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-01',
    -0.017,
    0.00,
    -0.017,
    false,
    '2025-11-01 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-01'
);

-- 2025-11-02
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-02',
    -0.004,
    0.00,
    -0.004,
    false,
    '2025-11-02 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-02'
);

-- 2025-11-03
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-03',
    -0.168,
    0.00,
    -0.168,
    false,
    '2025-11-03 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-03'
);

-- 2025-11-04 (11/4は既に存在する可能性が高いのでスキップされる)
INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
)
SELECT
    '2025-11-04',
    -0.695,
    0.00,
    -0.695,
    false,
    '2025-11-04 12:00:00+09'
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log WHERE date = '2025-11-04'
);

-- STEP 3: 挿入後の結果を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-04'
ORDER BY date;
