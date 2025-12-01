-- ========================================
-- 11月の紹介報酬を運用状況別に確認
-- ========================================

-- 1. 紹介報酬を受け取ったユーザーの運用状況
SELECT '=== 1. 紹介報酬受取ユーザーの運用状況 ===' as section;

WITH november_referral_users AS (
    SELECT DISTINCT user_id
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30'
)
SELECT
    CASE
        WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
        WHEN u.operation_start_date > '2025-11-30' THEN '運用開始前（12月以降）'
        WHEN u.operation_start_date <= '2025-11-01' THEN '運用中（11月開始前）'
        ELSE '運用中（11月中に開始）'
    END as operation_status,
    COUNT(DISTINCT nru.user_id) as user_count,
    SUM(urp.profit_amount) as total_referral_profit
FROM november_referral_users nru
INNER JOIN users u ON nru.user_id = u.user_id
LEFT JOIN user_referral_profit urp ON nru.user_id = urp.user_id
    AND urp.date >= '2025-11-01'
    AND urp.date <= '2025-11-30'
GROUP BY
    CASE
        WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
        WHEN u.operation_start_date > '2025-11-30' THEN '運用開始前（12月以降）'
        WHEN u.operation_start_date <= '2025-11-01' THEN '運用中（11月開始前）'
        ELSE '運用中（11月中に開始）'
    END
ORDER BY user_count DESC;

-- 2. 運用開始前なのに紹介報酬を受け取っているユーザー
SELECT '=== 2. 運用開始前なのに紹介報酬を受け取っているユーザー ===' as section;

SELECT
    u.user_id,
    u.email,
    u.operation_start_date,
    COUNT(DISTINCT urp.date) as days_with_referral,
    SUM(urp.profit_amount) as total_referral_profit,
    MIN(urp.date) as first_referral_date,
    MAX(urp.date) as last_referral_date
FROM user_referral_profit urp
INNER JOIN users u ON urp.user_id = u.user_id
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
  AND (
      u.operation_start_date IS NULL
      OR u.operation_start_date > urp.date
  )
GROUP BY u.user_id, u.email, u.operation_start_date
ORDER BY total_referral_profit DESC;

-- 3. 誤配布額の合計
SELECT '=== 3. 誤配布額の合計 ===' as section;

SELECT
    COUNT(DISTINCT urp.user_id) as incorrect_users,
    COUNT(*) as incorrect_records,
    SUM(urp.profit_amount) as total_incorrect_amount
FROM user_referral_profit urp
INNER JOIN users u ON urp.user_id = u.user_id
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
  AND (
      u.operation_start_date IS NULL
      OR u.operation_start_date > urp.date
  );

-- 4. 正しい紹介報酬（運用中のユーザーのみ）
SELECT '=== 4. 正しい紹介報酬（運用中のユーザーのみ） ===' as section;

SELECT
    COUNT(DISTINCT urp.user_id) as correct_users,
    COUNT(*) as correct_records,
    SUM(urp.profit_amount) as total_correct_amount
FROM user_referral_profit urp
INNER JOIN users u ON urp.user_id = u.user_id
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= urp.date;

-- 5. 日別の誤配布状況
SELECT '=== 5. 日別の誤配布状況 ===' as section;

SELECT
    urp.date,
    COUNT(DISTINCT CASE WHEN u.operation_start_date IS NULL OR u.operation_start_date > urp.date THEN urp.user_id END) as incorrect_users,
    SUM(CASE WHEN u.operation_start_date IS NULL OR u.operation_start_date > urp.date THEN urp.profit_amount ELSE 0 END) as incorrect_amount,
    COUNT(DISTINCT CASE WHEN u.operation_start_date IS NOT NULL AND u.operation_start_date <= urp.date THEN urp.user_id END) as correct_users,
    SUM(CASE WHEN u.operation_start_date IS NOT NULL AND u.operation_start_date <= urp.date THEN urp.profit_amount ELSE 0 END) as correct_amount
FROM user_referral_profit urp
INNER JOIN users u ON urp.user_id = u.user_id
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
GROUP BY urp.date
ORDER BY urp.date DESC;

-- サマリー
DO $$
DECLARE
    v_total_referral NUMERIC;
    v_correct_referral NUMERIC;
    v_incorrect_referral NUMERIC;
    v_incorrect_users INTEGER;
BEGIN
    -- 全体の紹介報酬
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_total_referral
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30';

    -- 正しい紹介報酬
    SELECT COALESCE(SUM(urp.profit_amount), 0)
    INTO v_correct_referral
    FROM user_referral_profit urp
    INNER JOIN users u ON urp.user_id = u.user_id
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= urp.date;

    -- 誤配布
    SELECT
        COUNT(DISTINCT urp.user_id),
        COALESCE(SUM(urp.profit_amount), 0)
    INTO v_incorrect_users, v_incorrect_referral
    FROM user_referral_profit urp
    INNER JOIN users u ON urp.user_id = u.user_id
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND (
          u.operation_start_date IS NULL
          OR u.operation_start_date > urp.date
      );

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 11月の紹介報酬検証';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '全体の紹介報酬: $%', v_total_referral;
    RAISE NOTICE '正しい紹介報酬: $%', v_correct_referral;
    RAISE NOTICE '誤配布額: $%', v_incorrect_referral;
    RAISE NOTICE '誤配布ユーザー数: %名', v_incorrect_users;
    RAISE NOTICE '';
    RAISE NOTICE '誤配布率: %.1f%%', (v_incorrect_referral / v_total_referral * 100);
    RAISE NOTICE '===========================================';
END $$;
