-- ========================================
-- 177B83のLevel 2紹介報酬の詳細確認
-- ========================================

-- 1. Level 2紹介報酬のレコード数と金額
SELECT '=== 1. 177B83のLevel 2紹介報酬の概要（11月） ===' as section;

SELECT
    referral_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT child_user_id) as unique_children,
    COUNT(DISTINCT date) as unique_dates,
    SUM(profit_amount) as total_profit,
    AVG(profit_amount) as avg_profit,
    MIN(profit_amount) as min_profit,
    MAX(profit_amount) as max_profit
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY referral_level
ORDER BY referral_level;

-- 2. Level 2の子ユーザー一覧
SELECT '=== 2. Level 2の子ユーザー一覧 ===' as section;

SELECT
    child_user_id,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_referral_profit
WHERE user_id = '177B83'
  AND referral_level = 2
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY child_user_id
ORDER BY total_profit DESC
LIMIT 20;

-- 3. 最も高額なLevel 2紹介報酬（11/26）
SELECT '=== 3. 11/26のLevel 2紹介報酬詳細 ===' as section;

SELECT
    urp.child_user_id,
    u.email,
    urp.profit_amount as recorded_profit,
    udp.daily_profit as child_daily_profit,
    (udp.daily_profit * 0.10) as expected_profit,
    (urp.profit_amount - udp.daily_profit * 0.10) as difference,
    COUNT(nm.id) as child_nft_count
FROM user_referral_profit urp
LEFT JOIN users u ON urp.child_user_id = u.user_id
LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
LEFT JOIN nft_master nm ON urp.child_user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE urp.user_id = '177B83'
  AND urp.referral_level = 2
  AND urp.date = '2025-11-26'
GROUP BY urp.child_user_id, u.email, urp.profit_amount, udp.daily_profit
ORDER BY urp.profit_amount DESC;

-- 4. 紹介ツリーの確認（177B83の下位ユーザー）
SELECT '=== 4. 177B83の紹介ツリー ===' as section;

-- Level 1（直接紹介）
WITH level1 AS (
    SELECT user_id, email, operation_start_date
    FROM users
    WHERE referrer_user_id = '177B83'
),
-- Level 2（間接紹介）
level2 AS (
    SELECT u.user_id, u.email, u.referrer_user_id, u.operation_start_date
    FROM users u
    INNER JOIN level1 l1 ON u.referrer_user_id = l1.user_id
)
SELECT
    '177B83' as root_user,
    l2.user_id as level2_user_id,
    l2.email as level2_email,
    l2.referrer_user_id as level1_user_id,
    (SELECT email FROM users WHERE user_id = l2.referrer_user_id) as level1_email,
    l2.operation_start_date,
    COUNT(nm.id) as nft_count
FROM level2 l2
LEFT JOIN nft_master nm ON l2.user_id = nm.user_id AND nm.buyback_date IS NULL
GROUP BY l2.user_id, l2.email, l2.referrer_user_id, l2.operation_start_date
ORDER BY l2.user_id;

-- 5. Level 2の特定ユーザーの日利確認（サンプル）
SELECT '=== 5. Level 2ユーザーの日利（11/26、上位5名） ===' as section;

WITH top_level2 AS (
    SELECT DISTINCT child_user_id
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND referral_level = 2
      AND date = '2025-11-26'
    ORDER BY profit_amount DESC
    LIMIT 5
)
SELECT
    udp.user_id,
    u.email,
    udp.daily_profit,
    COUNT(nm.id) as nft_count,
    (udp.daily_profit * 0.10) as expected_level2_profit,
    (
        SELECT profit_amount
        FROM user_referral_profit
        WHERE user_id = '177B83'
          AND child_user_id = udp.user_id
          AND referral_level = 2
          AND date = '2025-11-26'
    ) as actual_level2_profit
FROM user_daily_profit udp
INNER JOIN top_level2 tl2 ON udp.user_id = tl2.child_user_id
LEFT JOIN users u ON udp.user_id = u.user_id
LEFT JOIN nft_master nm ON udp.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE udp.date = '2025-11-26'
GROUP BY udp.user_id, u.email, udp.daily_profit
ORDER BY udp.daily_profit DESC;

-- 6. Level 2のレコード数が異常に多いか確認
SELECT '=== 6. 日別のLevel 2レコード数 ===' as section;

SELECT
    date,
    COUNT(*) as level2_record_count,
    COUNT(DISTINCT child_user_id) as unique_children,
    SUM(profit_amount) as total_profit,
    (COUNT(*) / NULLIF(COUNT(DISTINCT child_user_id), 0)) as records_per_child
FROM user_referral_profit
WHERE user_id = '177B83'
  AND referral_level = 2
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY date
ORDER BY date DESC;

-- サマリー
DO $$
DECLARE
    v_level2_total NUMERIC;
    v_level2_records INTEGER;
    v_unique_children INTEGER;
    v_expected_total NUMERIC;
BEGIN
    -- Level 2紹介報酬の合計
    SELECT
        SUM(profit_amount),
        COUNT(*),
        COUNT(DISTINCT child_user_id)
    INTO v_level2_total, v_level2_records, v_unique_children
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND referral_level = 2
      AND date >= '2025-11-01'
      AND date <= '2025-11-30';

    -- 期待値の計算（Level 2ユーザーの日利 × 10%）
    WITH level2_users AS (
        SELECT DISTINCT child_user_id
        FROM user_referral_profit
        WHERE user_id = '177B83'
          AND referral_level = 2
          AND date >= '2025-11-01'
          AND date <= '2025-11-30'
    )
    SELECT COALESCE(SUM(udp.daily_profit * 0.10), 0)
    INTO v_expected_total
    FROM user_daily_profit udp
    INNER JOIN level2_users l2 ON udp.user_id = l2.child_user_id
    WHERE udp.date >= '2025-11-01'
      AND udp.date <= '2025-11-30';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 177B83のLevel 2紹介報酬分析';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Level 2紹介報酬:';
    RAISE NOTICE '  レコード数: %', v_level2_records;
    RAISE NOTICE '  ユニーク子ユーザー数: %', v_unique_children;
    RAISE NOTICE '  合計金額: $%', v_level2_total;
    RAISE NOTICE '';
    RAISE NOTICE '期待値: $%', v_expected_total;
    RAISE NOTICE '実際: $%', v_level2_total;
    RAISE NOTICE '差額: $%', v_level2_total - v_expected_total;
    RAISE NOTICE '';
    IF v_unique_children > 0 THEN
        RAISE NOTICE '1人あたりのレコード数: %.1f', v_level2_records::NUMERIC / v_unique_children;
        IF v_level2_records::NUMERIC / v_unique_children > 30 THEN
            RAISE NOTICE '🚨 異常: 1人あたり30レコード以上（重複の可能性）';
        END IF;
    END IF;
    RAISE NOTICE '===========================================';
END $$;
