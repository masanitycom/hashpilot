-- ========================================
-- 11月の日利・紹介報酬の正確な総額
-- ========================================

-- 1. 11月の個人利益（日利）
SELECT '=== 1. 11月の個人利益（user_daily_profit） ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_count,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_daily_profit,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30';

-- 2. 11月の紹介報酬
SELECT '=== 2. 11月の紹介報酬（user_referral_profit） ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_count,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_referral_profit,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_referral_profit
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30';

-- 3. 11月の合計（個人利益 + 紹介報酬）
SELECT '=== 3. 11月の合計（個人利益 + 紹介報酬） ===' as section;

WITH personal AS (
    SELECT COALESCE(SUM(daily_profit), 0) as total
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
),
referral AS (
    SELECT COALESCE(SUM(profit_amount), 0) as total
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
)
SELECT
    p.total as personal_profit,
    r.total as referral_profit,
    (p.total + r.total) as grand_total
FROM personal p, referral r;

-- 4. 現在のaffiliate_cycleの合計available_usdt
SELECT '=== 4. 現在のaffiliate_cycleの合計 ===' as section;

SELECT
    COUNT(*) as total_users,
    SUM(available_usdt) as total_available_usdt,
    SUM(cum_usdt) as total_cum_usdt
FROM affiliate_cycle;

-- 5. 11月の配布額がavailable_usdtに反映されているか計算
SELECT '=== 5. available_usdtへの反映状況 ===' as section;

WITH november_total AS (
    SELECT
        COALESCE(SUM(udp.daily_profit), 0) + COALESCE(SUM(urp.profit_amount), 0) as total_distributed
    FROM user_daily_profit udp
    FULL OUTER JOIN user_referral_profit urp ON udp.user_id = urp.user_id AND udp.date = urp.date
    WHERE udp.date >= '2025-11-01' AND udp.date <= '2025-11-30'
       OR urp.date >= '2025-11-01' AND urp.date <= '2025-11-30'
),
current_balance AS (
    SELECT SUM(available_usdt) as total_available
    FROM affiliate_cycle
)
SELECT
    nt.total_distributed as november_distributed,
    cb.total_available as current_available_usdt,
    (cb.total_available - nt.total_distributed) as previous_balance_estimate
FROM november_total nt, current_balance cb;

-- サマリー
DO $$
DECLARE
    v_personal NUMERIC;
    v_referral NUMERIC;
    v_total NUMERIC;
    v_current_available NUMERIC;
    v_missing NUMERIC;
BEGIN
    -- 11月の個人利益
    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_personal
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    -- 11月の紹介報酬
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_referral
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    v_total := v_personal + v_referral;

    -- 現在のavailable_usdt合計
    SELECT COALESCE(SUM(available_usdt), 0)
    INTO v_current_available
    FROM affiliate_cycle;

    v_missing := v_total - v_current_available;

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 11月の配布状況サマリー';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '11月の配布額:';
    RAISE NOTICE '  個人利益: $%', v_personal;
    RAISE NOTICE '  紹介報酬: $%', v_referral;
    RAISE NOTICE '  合計: $%', v_total;
    RAISE NOTICE '';
    RAISE NOTICE '現在のavailable_usdt合計: $%', v_current_available;
    RAISE NOTICE '';
    IF v_missing > 0 THEN
        RAISE NOTICE '🚨 不足額: $%', v_missing;
        RAISE NOTICE '  → この金額をavailable_usdtに加算する必要があります';
    ELSIF v_missing < 0 THEN
        RAISE NOTICE '⚠️ 超過額: $%', ABS(v_missing);
        RAISE NOTICE '  → 11月以前の残高が含まれています';
    ELSE
        RAISE NOTICE '✅ 完全一致';
    END IF;
    RAISE NOTICE '===========================================';
END $$;
