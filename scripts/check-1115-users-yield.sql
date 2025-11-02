-- 11/15運用開始のユーザーに11/1の日利が誤って反映されていないか確認

-- 1. 11/15運用開始のユーザーを特定
SELECT
    id,
    email,
    full_name,
    operation_start_date,
    total_purchases,
    has_approved_nft
FROM users
WHERE operation_start_date = '2024-11-15'
ORDER BY email;

-- 2. 該当ユーザーの11/1の日利配布状況を確認
SELECT
    u.id,
    u.email,
    u.full_name,
    u.operation_start_date,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.investment_amount
FROM users u
LEFT JOIN user_daily_profit udp ON u.id = udp.user_id
WHERE u.operation_start_date = '2024-11-15'
  AND udp.date = '2024-11-01'
ORDER BY u.email;

-- 3. 運用開始日が未来（11/2以降）のユーザーで、11/1に日利が配布されているケースを確認
SELECT
    u.id,
    u.email,
    u.full_name,
    u.operation_start_date,
    udp.date,
    udp.daily_profit,
    udp.yield_rate
FROM users u
INNER JOIN user_daily_profit udp ON u.id = udp.user_id
WHERE u.operation_start_date > '2024-11-01'
  AND udp.date = '2024-11-01'
  AND u.has_approved_nft = true
ORDER BY u.operation_start_date, u.email;

-- 4. 11/1の日利配布の総数を確認
SELECT
    COUNT(*) as total_distributions,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2024-11-01';

-- 5. 運用開始日別のユーザー数を確認
SELECT
    operation_start_date,
    COUNT(*) as user_count
FROM users
WHERE has_approved_nft = true
  AND operation_start_date IS NOT NULL
GROUP BY operation_start_date
ORDER BY operation_start_date DESC
LIMIT 10;
