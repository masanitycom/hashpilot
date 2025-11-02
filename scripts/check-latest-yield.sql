-- 最新の日利設定を確認

SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;
