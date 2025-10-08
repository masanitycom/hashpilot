-- ========================================
-- 紹介報酬計算関数を作成（運用開始日チェック付き）
-- ========================================

-- 既存の関数を削除
DROP FUNCTION IF EXISTS calculate_daily_referral_rewards(VARCHAR, DATE);

-- 紹介報酬計算関数を作成
CREATE OR REPLACE FUNCTION calculate_daily_referral_rewards(
    p_user_id VARCHAR(6),
    p_date DATE
)
RETURNS TABLE(
    referral_user_id VARCHAR(6),
    referral_level INTEGER,
    referral_profit NUMERIC,
    referral_amount NUMERIC,
    calculation_date DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_level1_rate NUMERIC := 0.20;  -- 20%
    v_level2_rate NUMERIC := 0.10;  -- 10%
    v_level3_rate NUMERIC := 0.05;  -- 5%
BEGIN
    -- Level 1: 直接紹介者
    RETURN QUERY
    WITH level1_users AS (
        SELECT u.user_id
        FROM users u
        WHERE u.referrer_user_id = p_user_id
          AND u.has_approved_nft = true
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= p_date  -- ⭐ 運用開始日チェック
    ),
    level1_profits AS (
        SELECT
            l1.user_id,
            COALESCE(SUM(ndp.daily_profit), 0) as daily_profit
        FROM level1_users l1
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = l1.user_id AND ndp.date = p_date
        GROUP BY l1.user_id
    )
    SELECT
        lp.user_id::VARCHAR(6) as referral_user_id,
        1::INTEGER as referral_level,
        lp.daily_profit::NUMERIC as referral_profit,
        (lp.daily_profit * v_level1_rate)::NUMERIC as referral_amount,
        p_date::DATE as calculation_date
    FROM level1_profits lp
    WHERE lp.daily_profit > 0;

    -- Level 2: 間接紹介者（Level 1の紹介者）
    RETURN QUERY
    WITH level1_users AS (
        SELECT u.user_id
        FROM users u
        WHERE u.referrer_user_id = p_user_id
          AND u.has_approved_nft = true
    ),
    level2_users AS (
        SELECT u.user_id
        FROM users u
        INNER JOIN level1_users l1 ON u.referrer_user_id = l1.user_id
        WHERE u.has_approved_nft = true
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= p_date  -- ⭐ 運用開始日チェック
    ),
    level2_profits AS (
        SELECT
            l2.user_id,
            COALESCE(SUM(ndp.daily_profit), 0) as daily_profit
        FROM level2_users l2
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = l2.user_id AND ndp.date = p_date
        GROUP BY l2.user_id
    )
    SELECT
        lp.user_id::VARCHAR(6) as referral_user_id,
        2::INTEGER as referral_level,
        lp.daily_profit::NUMERIC as referral_profit,
        (lp.daily_profit * v_level2_rate)::NUMERIC as referral_amount,
        p_date::DATE as calculation_date
    FROM level2_profits lp
    WHERE lp.daily_profit > 0;

    -- Level 3: 間接紹介者（Level 2の紹介者）
    RETURN QUERY
    WITH level1_users AS (
        SELECT u.user_id
        FROM users u
        WHERE u.referrer_user_id = p_user_id
          AND u.has_approved_nft = true
    ),
    level2_users AS (
        SELECT u.user_id
        FROM users u
        INNER JOIN level1_users l1 ON u.referrer_user_id = l1.user_id
        WHERE u.has_approved_nft = true
    ),
    level3_users AS (
        SELECT u.user_id
        FROM users u
        INNER JOIN level2_users l2 ON u.referrer_user_id = l2.user_id
        WHERE u.has_approved_nft = true
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= p_date  -- ⭐ 運用開始日チェック
    ),
    level3_profits AS (
        SELECT
            l3.user_id,
            COALESCE(SUM(ndp.daily_profit), 0) as daily_profit
        FROM level3_users l3
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = l3.user_id AND ndp.date = p_date
        GROUP BY l3.user_id
    )
    SELECT
        lp.user_id::VARCHAR(6) as referral_user_id,
        3::INTEGER as referral_level,
        lp.daily_profit::NUMERIC as referral_profit,
        (lp.daily_profit * v_level3_rate)::NUMERIC as referral_amount,
        p_date::DATE as calculation_date
    FROM level3_profits lp
    WHERE lp.daily_profit > 0;

    RETURN;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION calculate_daily_referral_rewards(VARCHAR, DATE) TO anon;
GRANT EXECUTE ON FUNCTION calculate_daily_referral_rewards(VARCHAR, DATE) TO authenticated;

-- テスト実行
SELECT '=== テスト: 7E0A1Eの紹介報酬を計算 ===' as section;

SELECT
    referral_user_id,
    referral_level,
    referral_profit,
    referral_amount
FROM calculate_daily_referral_rewards('7E0A1E', CURRENT_DATE)
ORDER BY referral_level, referral_user_id;

-- 合計を確認
SELECT
    '合計紹介報酬' as label,
    COALESCE(SUM(referral_amount), 0) as total_referral_reward
FROM calculate_daily_referral_rewards('7E0A1E', CURRENT_DATE);

-- 633DF2が含まれているか確認
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM calculate_daily_referral_rewards('7E0A1E', CURRENT_DATE)
            WHERE referral_user_id = '633DF2'
        ) THEN '633DF2は紹介報酬に含まれています（運用開始済み）'
        ELSE '633DF2は紹介報酬に含まれていません（運用開始前）'
    END as result;

-- 完了メッセージ
SELECT '紹介報酬計算関数を作成しました' as completion_message;
SELECT 'Level 1: 20%, Level 2: 10%, Level 3: 5%' as rates;
SELECT '運用開始日チェック付き - 運用開始前のユーザーは除外' as feature;
