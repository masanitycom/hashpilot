-- ========================================
-- 全ユーザーの紹介報酬計算を検証
-- ========================================

-- 1. user_referral_profitテーブルの11月合計 vs ダッシュボード表示
SELECT '=== 1. 紹介報酬の計算方法の違い ===' as section;

-- user_referral_profitテーブルから集計（正）
WITH referral_from_table AS (
    SELECT
        user_id,
        SUM(profit_amount) as total_from_table
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30'
    GROUP BY user_id
),
-- ダッシュボードの計算方法（フロントエンド）を再現
referral_from_dashboard AS (
    SELECT
        u.user_id,
        -- ここでダッシュボードがどう計算しているか確認する必要がある
        -- 仮に monthly_profit_card の計算ロジックを確認
        0 as total_from_dashboard
    FROM users u
    WHERE u.has_approved_nft = true
)
SELECT
    rft.user_id,
    rft.total_from_table as db_table_total,
    rfd.total_from_dashboard as dashboard_display
FROM referral_from_table rft
LEFT JOIN referral_from_dashboard rfd ON rft.user_id = rfd.user_id
ORDER BY rft.total_from_table DESC
LIMIT 20;

-- 2. 紹介報酬が多いユーザーTOP20の詳細
SELECT '=== 2. 紹介報酬TOP20ユーザー ===' as section;

SELECT
    urp.user_id,
    u.email,
    SUM(urp.profit_amount) as total_referral_nov,
    COUNT(*) as record_count,
    COUNT(DISTINCT urp.child_user_id) as unique_children,
    COUNT(DISTINCT urp.date) as days_with_profit,
    SUM(CASE WHEN urp.referral_level = 1 THEN urp.profit_amount ELSE 0 END) as level1_total,
    SUM(CASE WHEN urp.referral_level = 2 THEN urp.profit_amount ELSE 0 END) as level2_total,
    SUM(CASE WHEN urp.referral_level = 3 THEN urp.profit_amount ELSE 0 END) as level3_total
FROM user_referral_profit urp
INNER JOIN users u ON urp.user_id = u.user_id
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
GROUP BY urp.user_id, u.email
ORDER BY total_referral_nov DESC
LIMIT 20;

-- 3. 紹介報酬の計算が正しいか検証（サンプル10名）
SELECT '=== 3. 紹介報酬計算の検証（サンプル10名） ===' as section;

WITH sample_users AS (
    SELECT user_id
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30'
    GROUP BY user_id
    ORDER BY SUM(profit_amount) DESC
    LIMIT 10
),
-- 各ユーザーの直接紹介者の日利を確認
child_daily_profits AS (
    SELECT
        urp.user_id as parent_user_id,
        urp.child_user_id,
        urp.date,
        urp.referral_level,
        urp.profit_amount as recorded_profit,
        udp.daily_profit as child_daily_profit,
        CASE
            WHEN urp.referral_level = 1 THEN udp.daily_profit * 0.20
            WHEN urp.referral_level = 2 THEN udp.daily_profit * 0.10
            WHEN urp.referral_level = 3 THEN udp.daily_profit * 0.05
        END as expected_profit
    FROM user_referral_profit urp
    INNER JOIN sample_users su ON urp.user_id = su.user_id
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
)
SELECT
    parent_user_id,
    child_user_id,
    date,
    referral_level,
    child_daily_profit,
    expected_profit,
    recorded_profit,
    (recorded_profit - expected_profit) as difference,
    CASE
        WHEN expected_profit = 0 THEN NULL
        ELSE ((recorded_profit - expected_profit) / expected_profit * 100)
    END as difference_pct
FROM child_daily_profits
WHERE expected_profit IS NOT NULL
  AND ABS(recorded_profit - expected_profit) > 0.01
ORDER BY ABS(difference) DESC
LIMIT 50;

-- 4. 11/30のみの検証
SELECT '=== 4. 11/30の紹介報酬計算検証（サンプル） ===' as section;

WITH referral_1130 AS (
    SELECT
        urp.user_id as parent_user_id,
        urp.child_user_id,
        urp.referral_level,
        urp.profit_amount as recorded_profit,
        udp.daily_profit as child_daily_profit,
        CASE
            WHEN urp.referral_level = 1 THEN udp.daily_profit * 0.20
            WHEN urp.referral_level = 2 THEN udp.daily_profit * 0.10
            WHEN urp.referral_level = 3 THEN udp.daily_profit * 0.05
        END as expected_profit
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date = '2025-11-30'
)
SELECT
    parent_user_id,
    child_user_id,
    referral_level,
    child_daily_profit,
    expected_profit,
    recorded_profit,
    (recorded_profit - expected_profit) as difference
FROM referral_1130
WHERE expected_profit IS NOT NULL
  AND ABS(recorded_profit - expected_profit) > 0.01
ORDER BY ABS(difference) DESC
LIMIT 50;

-- 5. 紹介報酬の統計（全ユーザー）
SELECT '=== 5. 紹介報酬の統計 ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_with_referral,
    SUM(profit_amount) as total_referral_all,
    MIN(profit_amount) as min_profit,
    MAX(profit_amount) as max_profit,
    AVG(profit_amount) as avg_profit,
    COUNT(*) as total_records
FROM user_referral_profit
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30';

-- 6. レベル別の統計
SELECT '=== 6. レベル別の紹介報酬統計 ===' as section;

SELECT
    referral_level,
    COUNT(DISTINCT user_id) as users_count,
    SUM(profit_amount) as total_profit,
    COUNT(*) as record_count,
    MIN(profit_amount) as min_profit,
    MAX(profit_amount) as max_profit,
    AVG(profit_amount) as avg_profit
FROM user_referral_profit
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY referral_level
ORDER BY referral_level;

-- サマリー
DO $$
DECLARE
    v_total_referral NUMERIC;
    v_total_daily NUMERIC;
    v_expected_level1 NUMERIC;
    v_expected_level2 NUMERIC;
    v_expected_level3 NUMERIC;
BEGIN
    -- 11月の紹介報酬合計
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_total_referral
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30';

    -- 11月の日利合計
    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_total_daily
    FROM user_daily_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30';

    -- 期待される紹介報酬
    v_expected_level1 := v_total_daily * 0.20;
    v_expected_level2 := v_total_daily * 0.10;
    v_expected_level3 := v_total_daily * 0.05;

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 11月の紹介報酬検証サマリー';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '11月の日利合計: $%', v_total_daily;
    RAISE NOTICE '11月の紹介報酬合計: $%', v_total_referral;
    RAISE NOTICE '';
    RAISE NOTICE '期待される紹介報酬:';
    RAISE NOTICE '  Level 1 (20%%): $%', v_expected_level1;
    RAISE NOTICE '  Level 2 (10%%): $%', v_expected_level2;
    RAISE NOTICE '  Level 3 (5%%): $%', v_expected_level3;
    RAISE NOTICE '  合計: $%', v_expected_level1 + v_expected_level2 + v_expected_level3;
    RAISE NOTICE '';
    RAISE NOTICE '実際の紹介報酬: $%', v_total_referral;
    RAISE NOTICE '差額: $%', v_total_referral - (v_expected_level1 + v_expected_level2 + v_expected_level3);
    RAISE NOTICE '===========================================';
END $$;
