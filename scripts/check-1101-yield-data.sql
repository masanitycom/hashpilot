-- 11/1の日利データを確認

SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    total_users,
    created_at
FROM daily_yield_log
WHERE date = '2024-11-01'
ORDER BY created_at DESC;

-- 最新5件も表示
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    total_users,
    created_at
FROM daily_yield_log
ORDER BY date DESC, created_at DESC
LIMIT 5;
