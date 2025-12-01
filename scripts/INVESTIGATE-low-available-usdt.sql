-- ========================================
-- なぜ available_usdt が少ないのか調査
-- ========================================

-- 1. NFT保有者の available_usdt 分布
SELECT '=== 1. NFT保有者（378名）の available_usdt 分布 ===' as section;

SELECT
    CASE
        WHEN ac.available_usdt >= 100 THEN '$100以上'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        WHEN ac.available_usdt >= 10 THEN '$10～$19'
        WHEN ac.available_usdt >= 1 THEN '$1～$9'
        ELSE '$0～$0.99'
    END as amount_range,
    COUNT(*) as user_count,
    SUM(ac.available_usdt) as total_amount,
    MIN(ac.available_usdt) as min,
    MAX(ac.available_usdt) as max,
    AVG(ac.available_usdt) as avg
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true
GROUP BY
    CASE
        WHEN ac.available_usdt >= 100 THEN '$100以上'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        WHEN ac.available_usdt >= 10 THEN '$10～$19'
        WHEN ac.available_usdt >= 1 THEN '$1～$9'
        ELSE '$0～$0.99'
    END
ORDER BY MIN(ac.available_usdt) DESC;

-- 2. available_usdt が $0～$9 のユーザーの詳細（サンプル20名）
SELECT '=== 2. available_usdt が $0～$9 のユーザー（サンプル20名） ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.available_usdt,
    ac.cum_usdt,
    ac.phase,
    ac.auto_nft_count,
    ac.manual_nft_count,
    COUNT(nm.id) as nft_count,
    u.operation_start_date
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.has_approved_nft = true
  AND ac.available_usdt < 10
GROUP BY u.user_id, u.email, u.full_name, ac.available_usdt, ac.cum_usdt, ac.phase,
         ac.auto_nft_count, ac.manual_nft_count, u.operation_start_date
ORDER BY ac.available_usdt DESC
LIMIT 20;

-- 3. 11/30の日利が配布されているか確認
SELECT '=== 3. 11/30の日利配布状況 ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_count,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_daily_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit,
    AVG(daily_profit) as avg_profit
FROM nft_daily_profit
WHERE date = '2025-11-30';

-- 4. 11/30の紹介報酬が配布されているか確認
SELECT '=== 4. 11/30の紹介報酬配布状況 ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_count,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_referral_profit,
    MIN(profit_amount) as min_profit,
    MAX(profit_amount) as max_profit,
    AVG(profit_amount) as avg_profit
FROM user_referral_profit
WHERE date = '2025-11-30';

-- 5. user_daily_profit テーブルの11/30データ
SELECT '=== 5. user_daily_profit の11/30データ ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_count,
    SUM(daily_profit) as total_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit,
    AVG(daily_profit) as avg_profit
FROM user_daily_profit
WHERE date = '2025-11-30';

-- 6. affiliate_cycle の累計確認
SELECT '=== 6. affiliate_cycle の累計統計 ===' as section;

SELECT
    COUNT(*) as total_users,
    SUM(available_usdt) as total_available,
    SUM(cum_usdt) as total_cum,
    AVG(available_usdt) as avg_available,
    AVG(cum_usdt) as avg_cum,
    MIN(available_usdt) as min_available,
    MAX(available_usdt) as max_available
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true;

-- 7. HOLDフェーズのユーザー数（cum_usdt >= 1100）
SELECT '=== 7. HOLDフェーズのユーザー ===' as section;

SELECT
    COUNT(*) as hold_phase_count,
    SUM(ac.available_usdt) as total_available,
    SUM(ac.cum_usdt) as total_cum,
    AVG(ac.cum_usdt) as avg_cum
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true
  AND ac.phase = 'HOLD';

-- 8. 最近の出金履歴（monthly_withdrawals）
SELECT '=== 8. 過去の月末出金履歴 ===' as section;

SELECT
    withdrawal_month,
    COUNT(*) as withdrawal_count,
    SUM(total_amount) as total_amount,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
    SUM(total_amount) FILTER (WHERE status = 'completed') as completed_amount
FROM monthly_withdrawals
GROUP BY withdrawal_month
ORDER BY withdrawal_month DESC;

-- 9. available_usdt が少ないユーザーの日利履歴（サンプル5名）
SELECT '=== 9. available_usdt が少ないユーザーの日利履歴（サンプル5名） ===' as section;

WITH low_balance_users AS (
    SELECT u.user_id
    FROM users u
    INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.has_approved_nft = true
      AND ac.available_usdt < 5
    ORDER BY u.user_id
    LIMIT 5
)
SELECT
    udp.user_id,
    COUNT(*) as daily_profit_records,
    SUM(udp.daily_profit) as total_daily_profit,
    MIN(udp.date) as first_date,
    MAX(udp.date) as last_date
FROM user_daily_profit udp
INNER JOIN low_balance_users lbu ON udp.user_id = lbu.user_id
GROUP BY udp.user_id
ORDER BY udp.user_id;

-- 10. 出金が完了しているユーザー（available_usdtが減っている原因？）
SELECT '=== 10. 完了済み出金の統計 ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_with_completed_withdrawal,
    COUNT(*) as completed_withdrawal_count,
    SUM(total_amount) as total_withdrawn,
    MIN(completed_at) as first_completed,
    MAX(completed_at) as last_completed
FROM monthly_withdrawals
WHERE status = 'completed';

-- サマリー
DO $$
DECLARE
    v_total_users INTEGER;
    v_nft_users INTEGER;
    v_eligible_users INTEGER;
    v_low_balance_users INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_users FROM users;

    SELECT COUNT(*) INTO v_nft_users
    FROM users WHERE has_approved_nft = true;

    SELECT COUNT(*) INTO v_eligible_users
    FROM users u
    INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.available_usdt >= 10;

    SELECT COUNT(*) INTO v_low_balance_users
    FROM users u
    INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.has_approved_nft = true AND ac.available_usdt < 10;

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 ユーザー分布サマリー';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '全ユーザー: %名', v_total_users;
    RAISE NOTICE 'NFT保有者: %名', v_nft_users;
    RAISE NOTICE '出金対象（>= $10）: %名', v_eligible_users;
    RAISE NOTICE '少額残高（< $10）: %名', v_low_balance_users;
    RAISE NOTICE '';
    RAISE NOTICE '問題: NFT保有者%名のうち、%名（%.1f%%）しか出金対象になっていない',
        v_nft_users,
        v_eligible_users,
        (v_eligible_users::NUMERIC / v_nft_users * 100);
    RAISE NOTICE '===========================================';
END $$;
