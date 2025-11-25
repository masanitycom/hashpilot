-- ========================================
-- 運用開始前のユーザーに利益が配布されていないか確認
-- ========================================

-- 2025-11-11の日利配布を確認
SELECT
    '運用開始前なのに日利が配布されているユーザー' as issue,
    ndp.user_id,
    u.full_name,
    u.operation_start_date,
    ndp.date as profit_date,
    SUM(ndp.daily_profit) as total_profit,
    COUNT(*) as record_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE ndp.date = '2025-11-11'
    AND (
        u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
    )
GROUP BY ndp.user_id, u.full_name, u.operation_start_date, ndp.date
ORDER BY total_profit DESC;

-- 紹介報酬も確認
SELECT
    '運用開始前なのに紹介報酬が配布されているユーザー（受取側）' as issue,
    urp.user_id,
    u.full_name,
    u.operation_start_date,
    urp.date as profit_date,
    SUM(urp.profit_amount) as total_referral_profit,
    COUNT(*) as record_count
FROM user_referral_profit urp
JOIN users u ON urp.user_id = u.user_id
WHERE urp.date = '2025-11-11'
    AND (
        u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
    )
GROUP BY urp.user_id, u.full_name, u.operation_start_date, urp.date
ORDER BY total_referral_profit DESC;

-- 紹介報酬の元になったユーザー（子ユーザー）の確認
SELECT
    '運用開始前なのに紹介報酬の元になっているユーザー（子側）' as issue,
    urp.child_user_id,
    u.full_name,
    u.operation_start_date,
    urp.date as profit_date,
    COUNT(DISTINCT urp.user_id) as referrer_count,
    SUM(urp.profit_amount) as total_referral_generated
FROM user_referral_profit urp
JOIN users u ON urp.child_user_id = u.user_id
WHERE urp.date = '2025-11-11'
    AND (
        u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
    )
GROUP BY urp.child_user_id, u.full_name, u.operation_start_date, urp.date
ORDER BY total_referral_generated DESC;

-- 全体のサマリー
SELECT
    '2025-11-11の配布サマリー' as label,
    COUNT(DISTINCT ndp.user_id) as users_with_profit,
    COUNT(DISTINCT CASE WHEN u.operation_start_date IS NULL OR u.operation_start_date > '2025-11-11' THEN ndp.user_id END) as violation_count,
    SUM(ndp.daily_profit) as total_profit,
    SUM(CASE WHEN u.operation_start_date IS NULL OR u.operation_start_date > '2025-11-11' THEN ndp.daily_profit ELSE 0 END) as violation_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE ndp.date = '2025-11-11';
