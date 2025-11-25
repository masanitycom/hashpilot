-- ========================================
-- 本番環境（V1システム）の利益と紹介報酬の分析
-- ========================================

-- ========================================
-- 1. 全体の累積利益サマリー
-- ========================================
SELECT
    '全体の累積利益' as label,
    COALESCE(SUM(ndp.daily_profit), 0) as total_personal_profit,
    COALESCE(SUM(urp.profit_amount), 0) as total_referral_profit,
    COALESCE(SUM(ndp.daily_profit), 0) + COALESCE(SUM(urp.profit_amount), 0) as total_combined_profit,
    COUNT(DISTINCT ndp.user_id) as users_with_personal_profit,
    COUNT(DISTINCT urp.user_id) as users_with_referral_profit
FROM nft_daily_profit ndp
FULL OUTER JOIN user_referral_profit urp ON ndp.user_id = urp.user_id AND ndp.date = urp.date;

-- ========================================
-- 2. 日付別の利益推移（最新10日）
-- ========================================
SELECT
    COALESCE(ndp.date, urp.date) as date,
    COALESCE(SUM(ndp.daily_profit), 0) as personal_profit,
    COALESCE(SUM(urp.profit_amount), 0) as referral_profit,
    COALESCE(SUM(ndp.daily_profit), 0) + COALESCE(SUM(urp.profit_amount), 0) as total_profit,
    COUNT(DISTINCT ndp.user_id) as users_with_personal,
    COUNT(DISTINCT urp.user_id) as users_with_referral
FROM (
    SELECT date, user_id, SUM(daily_profit) as daily_profit
    FROM nft_daily_profit
    GROUP BY date, user_id
) ndp
FULL OUTER JOIN (
    SELECT date, user_id, SUM(profit_amount) as profit_amount
    FROM user_referral_profit
    GROUP BY date, user_id
) urp ON ndp.user_id = urp.user_id AND ndp.date = urp.date
GROUP BY COALESCE(ndp.date, urp.date)
ORDER BY COALESCE(ndp.date, urp.date) DESC
LIMIT 10;

-- ========================================
-- 3. マイナス個人利益の日にプラス紹介報酬が発生しているか
-- ========================================
SELECT
    '★ マイナス個人利益日の紹介報酬' as issue,
    ndp_summary.date,
    ndp_summary.total_personal_profit,
    urp_summary.total_referral_profit,
    urp_summary.positive_referral_profit,
    urp_summary.negative_referral_profit,
    ndp_summary.users_count as users_with_personal,
    urp_summary.users_count as users_with_referral
FROM (
    SELECT
        date,
        SUM(daily_profit) as total_personal_profit,
        COUNT(DISTINCT user_id) as users_count
    FROM nft_daily_profit
    GROUP BY date
    HAVING SUM(daily_profit) < 0
) ndp_summary
LEFT JOIN (
    SELECT
        date,
        SUM(profit_amount) as total_referral_profit,
        SUM(CASE WHEN profit_amount > 0 THEN profit_amount ELSE 0 END) as positive_referral_profit,
        SUM(CASE WHEN profit_amount < 0 THEN profit_amount ELSE 0 END) as negative_referral_profit,
        COUNT(DISTINCT user_id) as users_count
    FROM user_referral_profit
    GROUP BY date
) urp_summary ON ndp_summary.date = urp_summary.date
ORDER BY ndp_summary.date DESC;

-- ========================================
-- 4. ユーザー別の累積利益（トップ20）
-- ========================================
SELECT
    'ユーザー別累積利益（トップ20）' as label,
    COALESCE(ndp.user_id, urp.user_id) as user_id,
    u.full_name,
    u.operation_start_date,
    u.is_pegasus_exchange,
    COALESCE(ndp.total_personal, 0) as total_personal_profit,
    COALESCE(urp.total_referral, 0) as total_referral_profit,
    COALESCE(ndp.total_personal, 0) + COALESCE(urp.total_referral, 0) as total_combined_profit,
    ac.available_usdt as available_usdt_in_cycle
FROM (
    SELECT user_id, SUM(daily_profit) as total_personal
    FROM nft_daily_profit
    GROUP BY user_id
) ndp
FULL OUTER JOIN (
    SELECT user_id, SUM(profit_amount) as total_referral
    FROM user_referral_profit
    GROUP BY user_id
) urp ON ndp.user_id = urp.user_id
LEFT JOIN users u ON COALESCE(ndp.user_id, urp.user_id) = u.user_id
LEFT JOIN affiliate_cycle ac ON COALESCE(ndp.user_id, urp.user_id) = ac.user_id
ORDER BY total_combined_profit DESC
LIMIT 20;

-- ========================================
-- 5. マイナス累積利益だがプラス紹介報酬のユーザー
-- ========================================
SELECT
    '★ マイナス累積だがプラス紹介報酬' as issue,
    COALESCE(ndp.user_id, urp.user_id) as user_id,
    u.full_name,
    u.operation_start_date,
    COALESCE(ndp.total_personal, 0) as total_personal_profit,
    COALESCE(urp.total_referral, 0) as total_referral_profit,
    COALESCE(ndp.total_personal, 0) + COALESCE(urp.total_referral, 0) as total_combined_profit
FROM (
    SELECT user_id, SUM(daily_profit) as total_personal
    FROM nft_daily_profit
    GROUP BY user_id
    HAVING SUM(daily_profit) < 0
) ndp
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as total_referral
    FROM user_referral_profit
    GROUP BY user_id
) urp ON ndp.user_id = urp.user_id
LEFT JOIN users u ON ndp.user_id = u.user_id
WHERE COALESCE(urp.total_referral, 0) > 0
ORDER BY total_combined_profit;

-- ========================================
-- 6. 紹介報酬の詳細（プラス/マイナス別）
-- ========================================
SELECT
    '紹介報酬の詳細' as label,
    SUM(profit_amount) as total_referral,
    SUM(CASE WHEN profit_amount > 0 THEN profit_amount ELSE 0 END) as total_positive,
    SUM(CASE WHEN profit_amount < 0 THEN profit_amount ELSE 0 END) as total_negative,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    COUNT(DISTINCT date) as date_count,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_referral_profit;

-- ========================================
-- 7. 運用開始前のユーザーに利益が発生しているか
-- ========================================
SELECT
    '★ 運用開始前のユーザーへの利益配布' as issue,
    ndp.date,
    ndp.user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    SUM(ndp.daily_profit) as daily_profit,
    COUNT(DISTINCT nm.id) as nft_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
LEFT JOIN nft_master nm ON ndp.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE (
    u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date
)
GROUP BY ndp.date, ndp.user_id, u.full_name, u.operation_start_date, u.has_approved_nft
ORDER BY ndp.date DESC, ndp.user_id
LIMIT 50;

-- ========================================
-- 8. affiliate_cycleの状態確認（異常値チェック）
-- ========================================
SELECT
    'affiliate_cycle異常値チェック' as label,
    COUNT(*) as total_users,
    SUM(CASE WHEN cum_usdt < 0 THEN 1 ELSE 0 END) as negative_cum_usdt,
    SUM(CASE WHEN available_usdt < 0 THEN 1 ELSE 0 END) as negative_available_usdt,
    SUM(CASE WHEN cum_usdt > 10000 THEN 1 ELSE 0 END) as very_high_cum_usdt,
    SUM(CASE WHEN available_usdt > 10000 THEN 1 ELSE 0 END) as very_high_available_usdt
FROM affiliate_cycle;

-- ========================================
-- 9. 最新の日利設定データ
-- ========================================
SELECT
    '最新の日利設定' as label,
    date,
    yield_rate,
    margin_rate,
    created_at
FROM user_daily_profit
GROUP BY date, yield_rate, margin_rate, created_at
ORDER BY date DESC
LIMIT 10;
