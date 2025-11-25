-- ===============================================
-- 運用開始日未設定ユーザーの誤配布日利を確認
-- ===============================================

-- 1. 全体概要
SELECT
    '全体概要' as section,
    COUNT(DISTINCT udp.user_id) as affected_users,
    COUNT(DISTINCT udp.date) as affected_dates,
    COALESCE(SUM(udp.daily_profit), 0) as total_incorrect_profit,
    MIN(udp.date) as first_date,
    MAX(udp.date) as last_date
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE u.operation_start_date IS NULL;

-- 2. ユーザー別詳細
SELECT
    '個別ユーザー' as section,
    u.user_id,
    u.email,
    u.full_name,
    u.operation_start_date,
    u.total_purchases,
    COUNT(DISTINCT udp.date) as days_count,
    COALESCE(SUM(udp.daily_profit), 0) as total_incorrect_profit,
    MIN(udp.date) as first_date,
    MAX(udp.date) as last_date,
    -- affiliate_cycleのavailable_usdt確認
    COALESCE(ac.available_usdt, 0) as current_available_usdt,
    COALESCE(ac.cum_usdt, 0) as current_cum_usdt
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date IS NULL
GROUP BY u.user_id, u.email, u.full_name, u.operation_start_date, u.total_purchases,
         ac.available_usdt, ac.cum_usdt
ORDER BY total_incorrect_profit DESC;

-- 3. 紹介報酬の誤配布確認
SELECT
    '紹介報酬' as section,
    COUNT(DISTINCT urp.user_id) as affected_referrers,
    COUNT(*) as incorrect_records,
    COALESCE(SUM(urp.profit_amount), 0) as total_incorrect_referral_profit,
    MIN(urp.date) as first_date,
    MAX(urp.date) as last_date
FROM user_referral_profit urp
INNER JOIN users u ON urp.child_user_id = u.user_id
WHERE u.operation_start_date IS NULL;

-- 4. 紹介報酬の詳細（紹介者別）
SELECT
    '紹介報酬詳細' as section,
    urp.user_id as referrer_id,
    u_ref.email as referrer_email,
    urp.child_user_id,
    u_child.email as child_email,
    u_child.operation_start_date as child_operation_start_date,
    COUNT(*) as records,
    COALESCE(SUM(urp.profit_amount), 0) as total_referral_profit
FROM user_referral_profit urp
INNER JOIN users u_child ON urp.child_user_id = u_child.user_id
LEFT JOIN users u_ref ON urp.user_id = u_ref.user_id
WHERE u_child.operation_start_date IS NULL
GROUP BY urp.user_id, u_ref.email, urp.child_user_id, u_child.email, u_child.operation_start_date
ORDER BY total_referral_profit DESC;
