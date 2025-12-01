-- ========================================
-- ユーザー177B83の11月の個人利益と紹介報酬
-- ========================================

-- 1. 基本情報
SELECT '=== 1. ユーザー177B83の基本情報 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.user_id = '177B83'
GROUP BY u.user_id, u.email, u.full_name, u.operation_start_date;

-- 2. 11月の個人利益（user_daily_profit）
SELECT '=== 2. 11月の個人利益（user_daily_profit） ===' as section;

SELECT
    user_id,
    COUNT(*) as days_count,
    SUM(daily_profit) as total_personal_profit,
    MIN(daily_profit) as min_daily,
    MAX(daily_profit) as max_daily,
    AVG(daily_profit) as avg_daily
FROM user_daily_profit
WHERE user_id = '177B83'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY user_id;

-- 3. 11月の紹介報酬（user_referral_profit）
SELECT '=== 3. 11月の紹介報酬（user_referral_profit） ===' as section;

SELECT
    user_id,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_referral_profit,
    SUM(CASE WHEN referral_level = 1 THEN profit_amount ELSE 0 END) as level1_total,
    SUM(CASE WHEN referral_level = 2 THEN profit_amount ELSE 0 END) as level2_total,
    SUM(CASE WHEN referral_level = 3 THEN profit_amount ELSE 0 END) as level3_total
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY user_id;

-- 4. 日別の詳細
SELECT '=== 4. 日別の個人利益と紹介報酬 ===' as section;

SELECT
    COALESCE(udp.date, urp_agg.date) as date,
    COALESCE(udp.daily_profit, 0) as personal_profit,
    COALESCE(urp_agg.referral_profit, 0) as referral_profit,
    COALESCE(udp.daily_profit, 0) + COALESCE(urp_agg.referral_profit, 0) as daily_total
FROM user_daily_profit udp
FULL OUTER JOIN (
    SELECT
        date,
        SUM(profit_amount) as referral_profit
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30'
    GROUP BY date
) urp_agg ON udp.date = urp_agg.date
WHERE udp.user_id = '177B83'
  AND COALESCE(udp.date, urp_agg.date) >= '2025-11-01'
  AND COALESCE(udp.date, urp_agg.date) <= '2025-11-30'
ORDER BY date;

-- 5. 現在のaffiliate_cycleの状態
SELECT '=== 5. 現在のaffiliate_cycleの状態 ===' as section;

SELECT
    user_id,
    available_usdt,
    cum_usdt,
    phase,
    auto_nft_count,
    manual_nft_count,
    updated_at AT TIME ZONE 'Asia/Tokyo' as updated_at_jst
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 6. ダッシュボード表示値（月次累積利益カードの計算を再現）
SELECT '=== 6. ダッシュボード表示値（11月） ===' as section;

WITH personal AS (
    SELECT COALESCE(SUM(daily_profit), 0) as total
    FROM user_daily_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30'
),
referral AS (
    SELECT COALESCE(SUM(profit_amount), 0) as total
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30'
)
SELECT
    p.total as personal_profit,
    r.total as referral_profit,
    (p.total + r.total) as total_profit
FROM personal p, referral r;

-- サマリー
DO $$
DECLARE
    v_personal NUMERIC;
    v_referral NUMERIC;
    v_total NUMERIC;
    v_available_usdt NUMERIC;
    v_nft_count INTEGER;
BEGIN
    -- 個人利益
    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_personal
    FROM user_daily_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30';

    -- 紹介報酬
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_referral
    FROM user_referral_profit
    WHERE user_id = '177B83'
      AND date >= '2025-11-01'
      AND date <= '2025-11-30';

    v_total := v_personal + v_referral;

    -- 現在のavailable_usdt
    SELECT available_usdt
    INTO v_available_usdt
    FROM affiliate_cycle
    WHERE user_id = '177B83';

    -- NFT数
    SELECT COUNT(*)
    INTO v_nft_count
    FROM nft_master
    WHERE user_id = '177B83' AND buyback_date IS NULL;

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 ユーザー177B83の11月サマリー';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'NFT保有数: %個', v_nft_count;
    RAISE NOTICE '';
    RAISE NOTICE '11月の利益:';
    RAISE NOTICE '  個人利益（日利）: $%', v_personal;
    RAISE NOTICE '  紹介報酬: $%', v_referral;
    RAISE NOTICE '  合計: $%', v_total;
    RAISE NOTICE '';
    RAISE NOTICE '現在のavailable_usdt: $%', v_available_usdt;
    RAISE NOTICE '';
    RAISE NOTICE 'ユーザーの期待値:';
    RAISE NOTICE '  ダッシュボード表示の11月累積利益: $%', v_total;
    RAISE NOTICE '  実際の表示: $1405.904';
    RAISE NOTICE '  差額: $%', 1405.904 - v_total;
    RAISE NOTICE '===========================================';
END $$;
