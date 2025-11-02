-- 11/1のデータを最終確認

SELECT
    date,
    yield_rate as "日利率（期待値: -0.02）",
    margin_rate as "マージン率（期待値: 30）",
    user_rate as "ユーザー受取率（期待値: -0.000084）",
    created_at
FROM daily_yield_log
WHERE date = '2025-11-01';

-- もし異常な値なら修正
UPDATE daily_yield_log
SET
    yield_rate = -0.02,
    margin_rate = 30.0,
    user_rate = -0.02 / 100 * (1 - 30.0 / 100) * 0.6
WHERE date = '2025-11-01'
AND (yield_rate != -0.02 OR margin_rate != 30.0);

-- 修正後確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate
FROM daily_yield_log
WHERE date = '2025-11-01';
