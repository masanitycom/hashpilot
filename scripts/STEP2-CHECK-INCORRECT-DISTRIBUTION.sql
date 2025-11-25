-- ========================================
-- STEP 2: 誤配布データの詳細確認
-- ========================================
-- このスクリプトで誤配布の全体像を把握します
-- 実行前にSTEP1でバックアップを作成してください
-- ========================================

-- ========================================
-- 1. 誤配布の合計金額サマリー
-- ========================================
SELECT
    '🚨 誤配布の合計金額' as summary,
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
-- 2. operation_start_date = NULL への個人利益配布（詳細）
-- ========================================
SELECT
    '🚨 operation_start_date = NULL への個人利益' as issue,
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
ORDER BY ndp.date DESC, total_daily_profit DESC
LIMIT 50;

-- ========================================
-- 3. operation_start_date > 配布日 への個人利益配布（詳細）
-- ========================================
SELECT
    '🚨 operation_start_date > 配布日 への個人利益' as issue,
    ndp.date,
    ndp.user_id,
    u.full_name,
    u.operation_start_date,
    (u.operation_start_date - ndp.date) as days_before_start,
    COUNT(ndp.id) as record_count,
    SUM(ndp.daily_profit) as total_daily_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NOT NULL
    AND u.operation_start_date > ndp.date
GROUP BY ndp.date, ndp.user_id, u.full_name, u.operation_start_date
ORDER BY ndp.date DESC, total_daily_profit DESC
LIMIT 50;

-- ========================================
-- 4. 日付別の誤配布金額
-- ========================================
SELECT
    '📅 日付別の誤配布金額' as label,
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
-- 5. 影響を受けたユーザーのリスト（累積金額順）
-- ========================================
SELECT
    '👤 影響を受けたユーザー（上位20件）' as label,
    COALESCE(ndp_summary.user_id, urp_summary.user_id) as user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    COALESCE(ndp_summary.total_personal, 0) as incorrect_personal_profit,
    COALESCE(urp_summary.total_referral, 0) as incorrect_referral_profit,
    COALESCE(ndp_summary.total_personal, 0) + COALESCE(urp_summary.total_referral, 0) as total_incorrect_profit,
    COUNT(DISTINCT nm.id) as nft_count,
    COALESCE(SUM(p.amount_usd * (1000.0 / 1100.0)), 0) as investment_value
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
JOIN users u ON COALESCE(ndp_summary.user_id, urp_summary.user_id) = u.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
GROUP BY ndp_summary.user_id, urp_summary.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, ndp_summary.total_personal, urp_summary.total_referral
ORDER BY total_incorrect_profit DESC
LIMIT 20;

-- ========================================
-- 6. affiliate_cycleへの影響
-- ========================================
SELECT
    '💰 affiliate_cycleへの影響（上位20件）' as label,
    affected_users.user_id,
    u.full_name,
    u.operation_start_date,
    ac.cum_usdt as current_cum_usdt,
    ac.available_usdt as current_available_usdt,
    ac.phase,
    affected_users.total_incorrect_profit,
    ac.cum_usdt - affected_users.incorrect_referral as corrected_cum_usdt,
    ac.available_usdt - affected_users.incorrect_personal as corrected_available_usdt
FROM (
    SELECT
        COALESCE(ndp_summary.user_id, urp_summary.user_id) as user_id,
        COALESCE(ndp_summary.total_personal, 0) as incorrect_personal,
        COALESCE(urp_summary.total_referral, 0) as incorrect_referral,
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
ORDER BY total_incorrect_profit DESC
LIMIT 20;

-- ========================================
-- 7. 削除対象のレコード数を確認
-- ========================================
SELECT
    '🗑️ 削除対象のレコード数' as label,
    (
        SELECT COUNT(*)
        FROM nft_daily_profit ndp
        JOIN users u ON ndp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > ndp.date
    ) as nft_daily_profit_records,
    (
        SELECT COUNT(*)
        FROM user_referral_profit urp
        JOIN users u ON urp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL
            OR u.operation_start_date > urp.date
    ) as user_referral_profit_records,
    (
        SELECT COUNT(DISTINCT u.user_id)
        FROM users u
        WHERE (
            u.user_id IN (
                SELECT DISTINCT ndp.user_id
                FROM nft_daily_profit ndp
                JOIN users u2 ON ndp.user_id = u2.user_id
                WHERE u2.operation_start_date IS NULL
                    OR u2.operation_start_date > ndp.date
            )
            OR u.user_id IN (
                SELECT DISTINCT urp.user_id
                FROM user_referral_profit urp
                JOIN users u2 ON urp.user_id = u2.user_id
                WHERE u2.operation_start_date IS NULL
                    OR u2.operation_start_date > urp.date
            )
        )
    ) as affected_users;

-- ========================================
-- 完了メッセージ
-- ========================================
SELECT
    '✅ 誤配布データの確認完了' as status,
    '次のステップ: STEP3-FIX-V1-FUNCTION.sql を実行してください' as next_step;

-- ========================================
-- 重要: 上記の結果を確認してから次のステップに進んでください
-- ========================================
