-- ========================================
-- 【緊急】運用開始前のユーザーへの誤配布を確認
-- ========================================

-- ========================================
-- 1. operation_start_date = NULL のユーザーへの個人利益配布
-- ========================================
SELECT
    '★ operation_start_date = NULL への個人利益' as issue,
    ndp.date,
    ndp.user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    u.is_pegasus_exchange,
    COUNT(ndp.id) as record_count,
    SUM(ndp.daily_profit) as total_daily_profit,
    COUNT(DISTINCT nm.id) as nft_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
LEFT JOIN nft_master nm ON ndp.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.operation_start_date IS NULL
GROUP BY ndp.date, ndp.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, u.is_pegasus_exchange
ORDER BY ndp.date DESC, total_daily_profit DESC;

-- ========================================
-- 2. operation_start_date > 配布日 のユーザーへの個人利益配布
-- ========================================
SELECT
    '★ operation_start_date > 配布日 への個人利益' as issue,
    ndp.date,
    ndp.user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    u.is_pegasus_exchange,
    (u.operation_start_date - ndp.date) as days_before_start,
    COUNT(ndp.id) as record_count,
    SUM(ndp.daily_profit) as total_daily_profit,
    COUNT(DISTINCT nm.id) as nft_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
LEFT JOIN nft_master nm ON ndp.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.operation_start_date IS NOT NULL
    AND u.operation_start_date > ndp.date
GROUP BY ndp.date, ndp.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, u.is_pegasus_exchange
ORDER BY ndp.date DESC, total_daily_profit DESC;

-- ========================================
-- 3. operation_start_date = NULL のユーザーへの紹介報酬配布
-- ========================================
SELECT
    '★ operation_start_date = NULL への紹介報酬' as issue,
    urp.date,
    urp.user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    urp.referral_level,
    COUNT(urp.id) as record_count,
    SUM(urp.profit_amount) as total_referral_profit
FROM user_referral_profit urp
JOIN users u ON urp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
GROUP BY urp.date, urp.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, urp.referral_level
ORDER BY urp.date DESC, total_referral_profit DESC;

-- ========================================
-- 4. operation_start_date > 配布日 のユーザーへの紹介報酬配布
-- ========================================
SELECT
    '★ operation_start_date > 配布日 への紹介報酬' as issue,
    urp.date,
    urp.user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    (u.operation_start_date - urp.date) as days_before_start,
    urp.referral_level,
    COUNT(urp.id) as record_count,
    SUM(urp.profit_amount) as total_referral_profit
FROM user_referral_profit urp
JOIN users u ON urp.user_id = u.user_id
WHERE u.operation_start_date IS NOT NULL
    AND u.operation_start_date > urp.date
GROUP BY urp.date, urp.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, urp.referral_level
ORDER BY urp.date DESC, total_referral_profit DESC;

-- ========================================
-- 5. 誤配布の合計金額サマリー
-- ========================================
SELECT
    '誤配布の合計金額' as summary,
    (
        SELECT COALESCE(SUM(ndp.daily_profit), 0)
        FROM nft_daily_profit ndp
        JOIN users u ON ndp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > ndp.date
    ) as incorrect_personal_profit,
    (
        SELECT COALESCE(SUM(urp.profit_amount), 0)
        FROM user_referral_profit urp
        JOIN users u ON urp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > urp.date
    ) as incorrect_referral_profit,
    (
        SELECT COALESCE(SUM(ndp.daily_profit), 0)
        FROM nft_daily_profit ndp
        JOIN users u ON ndp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > ndp.date
    ) + (
        SELECT COALESCE(SUM(urp.profit_amount), 0)
        FROM user_referral_profit urp
        JOIN users u ON urp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > urp.date
    ) as total_incorrect_profit;

-- ========================================
-- 6. 日付別の誤配布金額
-- ========================================
SELECT
    COALESCE(ndp_summary.date, urp_summary.date) as date,
    COALESCE(ndp_summary.incorrect_personal, 0) as incorrect_personal_profit,
    COALESCE(urp_summary.incorrect_referral, 0) as incorrect_referral_profit,
    COALESCE(ndp_summary.incorrect_personal, 0) + COALESCE(urp_summary.incorrect_referral, 0) as total_incorrect,
    COALESCE(ndp_summary.user_count, 0) as users_with_incorrect_personal,
    COALESCE(urp_summary.user_count, 0) as users_with_incorrect_referral
FROM (
    SELECT
        ndp.date,
        SUM(ndp.daily_profit) as incorrect_personal,
        COUNT(DISTINCT ndp.user_id) as user_count
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
    GROUP BY ndp.date
) ndp_summary
FULL OUTER JOIN (
    SELECT
        urp.date,
        SUM(urp.profit_amount) as incorrect_referral,
        COUNT(DISTINCT urp.user_id) as user_count
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
    GROUP BY urp.date
) urp_summary ON ndp_summary.date = urp_summary.date
ORDER BY COALESCE(ndp_summary.date, urp_summary.date) DESC;

-- ========================================
-- 7. 影響を受けたユーザーのリスト（累積金額順）
-- ========================================
SELECT
    '影響を受けたユーザー' as label,
    COALESCE(ndp_summary.user_id, urp_summary.user_id) as user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    u.is_pegasus_exchange,
    COALESCE(ndp_summary.total_personal, 0) as incorrect_personal_profit,
    COALESCE(urp_summary.total_referral, 0) as incorrect_referral_profit,
    COALESCE(ndp_summary.total_personal, 0) + COALESCE(urp_summary.total_referral, 0) as total_incorrect_profit,
    COALESCE(ndp_summary.record_count, 0) as personal_profit_records,
    COALESCE(urp_summary.record_count, 0) as referral_profit_records,
    COUNT(DISTINCT nm.id) as nft_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value
FROM (
    SELECT
        ndp.user_id,
        SUM(ndp.daily_profit) as total_personal,
        COUNT(ndp.id) as record_count
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
    GROUP BY ndp.user_id
) ndp_summary
FULL OUTER JOIN (
    SELECT
        urp.user_id,
        SUM(urp.profit_amount) as total_referral,
        COUNT(urp.id) as record_count
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
    GROUP BY urp.user_id
) urp_summary ON ndp_summary.user_id = urp_summary.user_id
JOIN users u ON COALESCE(ndp_summary.user_id, urp_summary.user_id) = u.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
GROUP BY ndp_summary.user_id, urp_summary.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, u.is_pegasus_exchange, ndp_summary.total_personal, urp_summary.total_referral, ndp_summary.record_count, urp_summary.record_count
ORDER BY total_incorrect_profit DESC;

-- ========================================
-- 8. affiliate_cycleへの影響
-- ========================================
SELECT
    'affiliate_cycleへの影響' as label,
    affected_users.user_id,
    u.full_name,
    u.operation_start_date,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase,
    ac.auto_nft_count,
    ac.manual_nft_count,
    affected_users.total_incorrect_profit
FROM (
    SELECT
        COALESCE(ndp_summary.user_id, urp_summary.user_id) as user_id,
        COALESCE(ndp_summary.total_personal, 0) + COALESCE(urp_summary.total_referral, 0) as total_incorrect_profit
    FROM (
        SELECT
            ndp.user_id,
            SUM(ndp.daily_profit) as total_personal
        FROM nft_daily_profit ndp
        JOIN users u ON ndp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > ndp.date
        GROUP BY ndp.user_id
    ) ndp_summary
    FULL OUTER JOIN (
        SELECT
            urp.user_id,
            SUM(urp.profit_amount) as total_referral
        FROM user_referral_profit urp
        JOIN users u ON urp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > urp.date
        GROUP BY urp.user_id
    ) urp_summary ON ndp_summary.user_id = urp_summary.user_id
) affected_users
JOIN users u ON affected_users.user_id = u.user_id
LEFT JOIN affiliate_cycle ac ON affected_users.user_id = ac.user_id
ORDER BY total_incorrect_profit DESC;
