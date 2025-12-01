-- ========================================
-- ユーザー177B83の紹介報酬を詳細確認
-- ========================================

-- 1. 基本情報
SELECT '=== 1. ユーザー177B83の基本情報 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.available_usdt,
    ac.cum_usdt,
    ac.phase,
    COUNT(nm.id) as nft_count,
    u.operation_start_date
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.user_id = '177B83'
GROUP BY u.user_id, u.email, u.full_name, ac.available_usdt, ac.cum_usdt,
         ac.phase, u.operation_start_date;

-- 2. 11月の紹介報酬（全レベル）
SELECT '=== 2. 11月の紹介報酬（全レベル） ===' as section;

SELECT
    date,
    referral_level,
    child_user_id,
    profit_amount,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
ORDER BY date DESC, referral_level;

-- 3. 11月の紹介報酬集計（レベル別）
SELECT '=== 3. 11月の紹介報酬集計（レベル別） ===' as section;

SELECT
    referral_level,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit,
    MIN(profit_amount) as min_profit,
    MAX(profit_amount) as max_profit,
    AVG(profit_amount) as avg_profit
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY referral_level
ORDER BY referral_level;

-- 4. 11月の紹介報酬合計
SELECT '=== 4. 11月の紹介報酬合計 ===' as section;

SELECT
    SUM(profit_amount) as total_referral_profit_nov,
    COUNT(*) as total_records,
    COUNT(DISTINCT date) as days_with_profit,
    COUNT(DISTINCT child_user_id) as unique_children
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30';

-- 5. 直接紹介（Level 1）のユーザーリスト
SELECT '=== 5. 直接紹介（Level 1）のユーザー ===' as section;

SELECT DISTINCT
    urp.child_user_id,
    u.email,
    COUNT(DISTINCT urp.date) as days_with_profit,
    SUM(urp.profit_amount) as total_profit_from_this_user,
    MIN(urp.date) as first_profit_date,
    MAX(urp.date) as last_profit_date
FROM user_referral_profit urp
LEFT JOIN users u ON urp.child_user_id = u.user_id
WHERE urp.user_id = '177B83'
  AND urp.referral_level = 1
  AND urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
GROUP BY urp.child_user_id, u.email
ORDER BY total_profit_from_this_user DESC;

-- 6. ダッシュボードで表示される紹介報酬の計算（フロントエンド再現）
SELECT '=== 6. ダッシュボード表示の計算（フロントエンド再現） ===' as section;

WITH monthly_referral AS (
    SELECT
        SUM(profit_amount) as total_referral
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30'
)
SELECT
    total_referral as calculated_referral,
    1101.2816 as expected_referral,
    (total_referral - 1101.2816) as difference,
    ((total_referral - 1101.2816) / 1101.2816 * 100) as difference_pct
FROM monthly_referral;

-- 7. 全期間の紹介報酬
SELECT '=== 7. 全期間の紹介報酬 ===' as section;

SELECT
    TO_CHAR(date, 'YYYY-MM') as year_month,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit
FROM user_referral_profit
WHERE user_id = '177B83'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY year_month DESC;

-- 8. 11/30の紹介報酬詳細（当日のみ）
SELECT '=== 8. 11/30の紹介報酬詳細 ===' as section;

SELECT
    referral_level,
    child_user_id,
    profit_amount,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date = '2025-11-30'
ORDER BY referral_level, profit_amount DESC;

-- 9. 11/30の紹介報酬合計（当日のみ）
SELECT '=== 9. 11/30の紹介報酬合計 ===' as section;

SELECT
    SUM(profit_amount) as total_1130_referral,
    COUNT(*) as record_count_1130,
    COUNT(DISTINCT child_user_id) as unique_children_1130
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date = '2025-11-30';

-- サマリー
DO $$
DECLARE
    v_total_nov NUMERIC;
    v_expected NUMERIC := 1101.2816;
    v_difference NUMERIC;
BEGIN
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_total_nov
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30';

    v_difference := v_total_nov - v_expected;

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 ユーザー177B83の紹介報酬サマリー';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '11月の紹介報酬合計: $%', v_total_nov;
    RAISE NOTICE '期待値: $%', v_expected;
    RAISE NOTICE '差額: $%', v_difference;
    RAISE NOTICE '差額率: %.2f%%', (v_difference / v_expected * 100);
    RAISE NOTICE '';
    IF v_difference > 0 THEN
        RAISE NOTICE '🚨 問題: 紹介報酬が期待値より $% 多い', v_difference;
    ELSIF v_difference < 0 THEN
        RAISE NOTICE '🚨 問題: 紹介報酬が期待値より $% 少ない', ABS(v_difference);
    ELSE
        RAISE NOTICE '✅ 紹介報酬は期待値と一致';
    END IF;
    RAISE NOTICE '===========================================';
END $$;
