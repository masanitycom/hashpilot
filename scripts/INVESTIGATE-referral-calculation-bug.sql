-- ========================================
-- 紹介報酬の計算が正しいか詳細調査
-- ========================================

-- 1. 11/30の個人利益と紹介報酬の比較
SELECT '=== 1. 11/30の個人利益 vs 紹介報酬 ===' as section;

WITH daily_profit_1130 AS (
    SELECT
        SUM(daily_profit) as total_daily_profit
    FROM user_daily_profit
    WHERE date = '2025-11-30'
),
referral_profit_1130 AS (
    SELECT
        SUM(profit_amount) as total_referral_profit
    FROM user_referral_profit
    WHERE date = '2025-11-30'
)
SELECT
    dp.total_daily_profit,
    rp.total_referral_profit,
    (rp.total_referral_profit / dp.total_daily_profit) as ratio,
    (dp.total_daily_profit * 0.35) as expected_referral,
    (rp.total_referral_profit - dp.total_daily_profit * 0.35) as difference
FROM daily_profit_1130 dp, referral_profit_1130 rp;

-- 2. 11月全体の個人利益 vs 紹介報酬
SELECT '=== 2. 11月全体の個人利益 vs 紹介報酬 ===' as section;

WITH daily_profit_nov AS (
    SELECT
        SUM(daily_profit) as total_daily_profit
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
),
referral_profit_nov AS (
    SELECT
        SUM(profit_amount) as total_referral_profit
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
)
SELECT
    dp.total_daily_profit,
    rp.total_referral_profit,
    (rp.total_referral_profit / dp.total_daily_profit) as ratio,
    (dp.total_daily_profit * 0.35) as expected_referral,
    (rp.total_referral_profit - dp.total_daily_profit * 0.35) as difference
FROM daily_profit_nov dp, referral_profit_nov rp;

-- 3. 紹介報酬レベル別の内訳（11月全体）
SELECT '=== 3. 紹介報酬レベル別の内訳（11月） ===' as section;

SELECT
    referral_level,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit,
    AVG(profit_amount) as avg_profit,
    MIN(profit_amount) as min_profit,
    MAX(profit_amount) as max_profit
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
GROUP BY referral_level
ORDER BY referral_level;

-- 4. 期待される紹介報酬レベル別（理論値）
SELECT '=== 4. 期待される紹介報酬レベル別（理論値） ===' as section;

WITH total_daily AS (
    SELECT SUM(daily_profit) as total
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
)
SELECT
    1 as referral_level,
    '20%' as rate,
    (total * 0.20) as expected_amount
FROM total_daily
UNION ALL
SELECT
    2 as referral_level,
    '10%' as rate,
    (total * 0.10) as expected_amount
FROM total_daily
UNION ALL
SELECT
    3 as referral_level,
    '5%' as rate,
    (total * 0.05) as expected_amount
FROM total_daily;

-- 5. サンプルユーザーの紹介報酬計算を検証（11/30のみ）
SELECT '=== 5. サンプルユーザーの計算検証（11/30、上位10名） ===' as section;

WITH user_totals AS (
    SELECT
        urp.user_id,
        SUM(urp.profit_amount) as total_referral_1130
    FROM user_referral_profit urp
    WHERE urp.date = '2025-11-30'
    GROUP BY urp.user_id
    ORDER BY total_referral_1130 DESC
    LIMIT 10
)
SELECT
    ut.user_id,
    u.email,
    ut.total_referral_1130,
    -- 直接紹介者の日利を集計
    (
        SELECT COALESCE(SUM(udp.daily_profit * 0.20), 0)
        FROM user_referral_profit urp2
        INNER JOIN user_daily_profit udp ON urp2.child_user_id = udp.user_id AND urp2.date = udp.date
        WHERE urp2.user_id = ut.user_id
          AND urp2.date = '2025-11-30'
          AND urp2.referral_level = 1
    ) as expected_level1,
    -- Level 2
    (
        SELECT COALESCE(SUM(udp.daily_profit * 0.10), 0)
        FROM user_referral_profit urp2
        INNER JOIN user_daily_profit udp ON urp2.child_user_id = udp.user_id AND urp2.date = udp.date
        WHERE urp2.user_id = ut.user_id
          AND urp2.date = '2025-11-30'
          AND urp2.referral_level = 2
    ) as expected_level2,
    -- Level 3
    (
        SELECT COALESCE(SUM(udp.daily_profit * 0.05), 0)
        FROM user_referral_profit urp2
        INNER JOIN user_daily_profit udp ON urp2.child_user_id = udp.user_id AND urp2.date = udp.date
        WHERE urp2.user_id = ut.user_id
          AND urp2.date = '2025-11-30'
          AND urp2.referral_level = 3
    ) as expected_level3
FROM user_totals ut
INNER JOIN users u ON ut.user_id = u.user_id
ORDER BY ut.total_referral_1130 DESC;

-- 6. 1人のユーザーの詳細（最も紹介報酬が多いユーザー）
SELECT '=== 6. 最も紹介報酬が多いユーザーの詳細（11/30） ===' as section;

WITH top_user AS (
    SELECT user_id
    FROM user_referral_profit
    WHERE date = '2025-11-30'
    GROUP BY user_id
    ORDER BY SUM(profit_amount) DESC
    LIMIT 1
)
SELECT
    urp.user_id,
    urp.child_user_id,
    urp.referral_level,
    urp.profit_amount as recorded_profit,
    udp.daily_profit as child_daily_profit,
    CASE
        WHEN urp.referral_level = 1 THEN udp.daily_profit * 0.20
        WHEN urp.referral_level = 2 THEN udp.daily_profit * 0.10
        WHEN urp.referral_level = 3 THEN udp.daily_profit * 0.05
    END as expected_profit,
    (urp.profit_amount -
        CASE
            WHEN urp.referral_level = 1 THEN udp.daily_profit * 0.20
            WHEN urp.referral_level = 2 THEN udp.daily_profit * 0.10
            WHEN urp.referral_level = 3 THEN udp.daily_profit * 0.05
        END
    ) as difference
FROM user_referral_profit urp
INNER JOIN top_user tu ON urp.user_id = tu.user_id
LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
WHERE urp.date = '2025-11-30'
ORDER BY ABS(urp.profit_amount -
    CASE
        WHEN urp.referral_level = 1 THEN udp.daily_profit * 0.20
        WHEN urp.referral_level = 2 THEN udp.daily_profit * 0.10
        WHEN urp.referral_level = 3 THEN udp.daily_profit * 0.05
    END
) DESC
LIMIT 20;

-- 7. 日別の異常な比率
SELECT '=== 7. 日別の個人利益 vs 紹介報酬比率 ===' as section;

SELECT
    COALESCE(udp.date, urp.date) as date,
    COALESCE(SUM(udp.daily_profit), 0) as total_daily_profit,
    COALESCE(SUM(urp.profit_amount), 0) as total_referral_profit,
    CASE
        WHEN COALESCE(SUM(udp.daily_profit), 0) = 0 THEN NULL
        ELSE COALESCE(SUM(urp.profit_amount), 0) / COALESCE(SUM(udp.daily_profit), 0)
    END as ratio,
    CASE
        WHEN COALESCE(SUM(udp.daily_profit), 0) = 0 THEN NULL
        WHEN COALESCE(SUM(urp.profit_amount), 0) / COALESCE(SUM(udp.daily_profit), 0) > 1.0 THEN '🚨 異常'
        WHEN COALESCE(SUM(urp.profit_amount), 0) / COALESCE(SUM(udp.daily_profit), 0) > 0.4 THEN '⚠️ 高い'
        ELSE '✅ 正常'
    END as status
FROM user_daily_profit udp
FULL OUTER JOIN user_referral_profit urp ON udp.date = urp.date
WHERE COALESCE(udp.date, urp.date) >= '2025-11-01'
  AND COALESCE(udp.date, urp.date) <= '2025-11-30'
GROUP BY COALESCE(udp.date, urp.date)
ORDER BY date DESC;

-- サマリー
DO $$
DECLARE
    v_total_daily NUMERIC;
    v_total_referral NUMERIC;
    v_expected_referral NUMERIC;
    v_ratio NUMERIC;
BEGIN
    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_total_daily
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_total_referral
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    v_expected_referral := v_total_daily * 0.35;
    v_ratio := v_total_referral / NULLIF(v_total_daily, 0);

    RAISE NOTICE '===========================================';
    RAISE NOTICE '🔍 紹介報酬計算の検証';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '11月の個人利益: $%', v_total_daily;
    RAISE NOTICE '11月の紹介報酬（実際）: $%', v_total_referral;
    RAISE NOTICE '11月の紹介報酬（期待値）: $%', v_expected_referral;
    RAISE NOTICE '';
    RAISE NOTICE '比率:';
    RAISE NOTICE '  実際: %.2f倍', v_ratio;
    RAISE NOTICE '  期待値: 0.35倍（20%% + 10%% + 5%%）';
    RAISE NOTICE '';
    RAISE NOTICE '差額: $%', v_total_referral - v_expected_referral;
    RAISE NOTICE '';
    IF v_ratio > 1.0 THEN
        RAISE NOTICE '🚨 重大な問題: 紹介報酬が個人利益を超えています！';
    ELSIF v_ratio > 0.5 THEN
        RAISE NOTICE '⚠️ 警告: 紹介報酬の比率が異常に高いです';
    ELSE
        RAISE NOTICE '✅ 比率は正常範囲内です';
    END IF;
    RAISE NOTICE '===========================================';
END $$;
