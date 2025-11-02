-- 11/1の日利処理で運用開始日チェックが正しく機能しているか確認

-- 1. 11/15運用開始のユーザーが11/1に日利を受け取っていないか確認
WITH operation_1115_users AS (
    SELECT
        u.user_id,
        u.email,
        u.full_name,
        u.operation_start_date,
        u.has_approved_nft,
        ac.total_nft_count
    FROM users u
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.operation_start_date = '2024-11-15'
)
SELECT
    ou.user_id,
    ou.email,
    ou.full_name,
    ou.operation_start_date,
    ou.total_nft_count,
    ndp.nft_id,
    ndp.date,
    ndp.daily_profit,
    ndp.yield_rate,
    '❌ ERROR: 運用開始前なのに日利が配布されている' as status
FROM operation_1115_users ou
INNER JOIN nft_daily_profit ndp ON ou.user_id = ndp.user_id
WHERE ndp.date = '2024-11-01'
ORDER BY ou.email;

-- 2. 11/1より後に運用開始するユーザーで、11/1に日利が配布されているケース
SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.operation_start_date,
    ndp.date,
    ndp.daily_profit,
    '❌ ERROR: 運用開始前なのに日利が配布されている' as status
FROM users u
INNER JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE u.operation_start_date > '2024-11-01'
  AND ndp.date = '2024-11-01'
ORDER BY u.operation_start_date, u.email;

-- 3. 11/1に運用開始済みのユーザー数（正しく配布されているべき）
SELECT
    COUNT(DISTINCT u.user_id) as users_eligible_for_1101,
    COUNT(DISTINCT ndp.user_id) as users_received_1101,
    COUNT(DISTINCT u.user_id) - COUNT(DISTINCT ndp.user_id) as missing_users
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id AND ndp.date = '2024-11-01'
WHERE u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2024-11-01'
  AND u.has_approved_nft = true;

-- 4. 運用開始日別の11/1日利配布状況
SELECT
    u.operation_start_date,
    COUNT(DISTINCT u.user_id) as total_users,
    COUNT(DISTINCT CASE WHEN ndp.date = '2024-11-01' THEN ndp.user_id END) as received_1101_yield,
    CASE
        WHEN u.operation_start_date <= '2024-11-01' THEN '✅ 配布されるべき'
        ELSE '❌ 配布されるべきではない'
    END as expected_status
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id AND ndp.date = '2024-11-01'
WHERE u.operation_start_date IS NOT NULL
  AND u.has_approved_nft = true
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date DESC
LIMIT 20;

-- 5. 11/15運用開始ユーザーの詳細情報
SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    ac.total_nft_count,
    ac.available_usdt,
    ac.cum_usdt,
    (SELECT COUNT(*) FROM nft_daily_profit WHERE user_id = u.user_id AND date = '2024-11-01') as profit_count_1101
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2024-11-15'
ORDER BY u.email;
