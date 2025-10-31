-- ========================================
-- 未入金ユーザーへの紹介報酬確認
-- ========================================

-- 1. 未入金だが紹介者を持つユーザー
SELECT '=== 1. 未入金だが紹介者を持つユーザー ===' as section;

SELECT
    user_id,
    email,
    full_name,
    referrer_user_id,
    total_purchases,
    created_at,
    (SELECT COUNT(*) FROM users u2 WHERE u2.referrer_user_id = users.user_id) as direct_referrals
FROM users
WHERE total_purchases = 0
    AND referrer_user_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;

-- 2. 未入金だが下に紹介者がいるユーザー
SELECT '=== 2. 未入金だが下に紹介者がいるユーザー ===' as section;

WITH referral_counts AS (
    SELECT
        referrer_user_id,
        COUNT(*) as referral_count,
        COUNT(*) FILTER (WHERE total_purchases > 0) as paid_referral_count
    FROM users
    WHERE referrer_user_id IS NOT NULL
    GROUP BY referrer_user_id
)
SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.total_purchases,
    rc.referral_count,
    rc.paid_referral_count
FROM users u
INNER JOIN referral_counts rc ON u.user_id = rc.referrer_user_id
WHERE u.total_purchases = 0
ORDER BY rc.paid_referral_count DESC, rc.referral_count DESC;

-- 3. 現在の日利計算関数で紹介報酬がどう計算されるか
SELECT '=== 3. 紹介報酬の計算ロジック確認 ===' as section;

-- process_daily_yield_with_cycles関数の定義を確認
SELECT
    proname as function_name,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';

-- 4. 未入金ユーザーがもらっている紹介報酬があるか確認
SELECT '=== 4. 未入金ユーザーのaffiliate_cycle確認 ===' as section;

SELECT
    ac.user_id,
    u.email,
    u.total_purchases,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase,
    ac.manual_nft_count,
    ac.auto_nft_count
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE u.total_purchases = 0
    AND (ac.cum_usdt > 0 OR ac.available_usdt > 0)
ORDER BY ac.cum_usdt DESC;

-- 5. 統計サマリー
SELECT '=== 5. 統計サマリー ===' as section;

SELECT
    COUNT(*) FILTER (WHERE total_purchases = 0) as unpaid_users,
    COUNT(*) FILTER (WHERE total_purchases = 0 AND referrer_user_id IS NOT NULL) as unpaid_with_referrer,
    COUNT(*) FILTER (WHERE total_purchases = 0 AND (
        SELECT COUNT(*) FROM users u2 WHERE u2.referrer_user_id = users.user_id
    ) > 0) as unpaid_with_referrals,
    COUNT(*) FILTER (WHERE total_purchases = 0 AND (
        SELECT COUNT(*) FROM users u2 WHERE u2.referrer_user_id = users.user_id AND u2.total_purchases > 0
    ) > 0) as unpaid_with_paid_referrals
FROM users;

SELECT '✅ 調査完了' as status;
