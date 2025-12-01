-- ========================================
-- ユーザー039483の詳細調査
-- なぜ日利$0なのに紹介報酬が発生したのか？
-- ========================================

-- 1. 基本情報
SELECT '=== 1. ユーザー039483の基本情報 ===' as section;

SELECT
    user_id,
    email,
    full_name,
    referrer_user_id,
    has_approved_nft,
    operation_start_date,
    created_at
FROM users
WHERE user_id = '039483';

-- 2. NFT保有状況
SELECT '=== 2. NFT保有状況 ===' as section;

SELECT
    id,
    nft_type,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '039483'
ORDER BY acquired_date;

-- 3. 11月の日利レコード
SELECT '=== 3. 11月の日利レコード（user_daily_profit） ===' as section;

SELECT
    date,
    daily_profit,
    phase,
    created_at
FROM user_daily_profit
WHERE user_id = '039483'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
ORDER BY date;

-- 4. 11月の親への紹介報酬
SELECT '=== 4. 親への紹介報酬（user_referral_profit） ===' as section;

SELECT
    urp.user_id as parent_user_id,
    u.email as parent_email,
    urp.date,
    urp.referral_level,
    urp.profit_amount,
    urp.created_at
FROM user_referral_profit urp
INNER JOIN users u ON urp.user_id = u.user_id
WHERE urp.child_user_id = '039483'
  AND urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
ORDER BY urp.date, urp.referral_level;

-- 5. 11/26の詳細
SELECT '=== 5. 11/26の詳細 ===' as section;

WITH user_info AS (
    SELECT
        user_id,
        has_approved_nft,
        operation_start_date,
        referrer_user_id
    FROM users
    WHERE user_id = '039483'
),
nft_count AS (
    SELECT COUNT(*) as count
    FROM nft_master
    WHERE user_id = '039483'
      AND buyback_date IS NULL
),
daily_profit AS (
    SELECT daily_profit
    FROM user_daily_profit
    WHERE user_id = '039483'
      AND date = '2025-11-26'
),
referral_to_parents AS (
    SELECT
        user_id as parent_user_id,
        referral_level,
        profit_amount
    FROM user_referral_profit
    WHERE child_user_id = '039483'
      AND date = '2025-11-26'
)
SELECT
    ui.user_id,
    ui.has_approved_nft,
    ui.operation_start_date,
    CASE
        WHEN ui.operation_start_date IS NULL THEN '未設定'
        WHEN ui.operation_start_date > '2025-11-26' THEN '未開始'
        ELSE '開始済み'
    END as operation_status,
    nc.count as nft_count,
    COALESCE(dp.daily_profit, 0) as daily_profit_1126,
    (
        SELECT COUNT(*)
        FROM referral_to_parents
    ) as referral_records_count,
    (
        SELECT SUM(profit_amount)
        FROM referral_to_parents
    ) as total_referral_to_parents
FROM user_info ui
CROSS JOIN nft_count nc
LEFT JOIN daily_profit dp ON true;

-- 6. V1関数の条件を再現
SELECT '=== 6. V1関数のSTEP 3条件チェック ===' as section;

-- ✅ STEP 3で紹介報酬計算対象になる条件:
SELECT
    u.user_id,
    u.has_approved_nft,
    u.operation_start_date,
    u.referrer_user_id,
    COUNT(nm.id) as nft_count,
    CASE
        WHEN nm.buyback_date IS NULL THEN '✅ NFT有効'
        ELSE '❌ 買い戻し済み'
    END as nft_status,
    CASE
        WHEN u.has_approved_nft = true THEN '✅'
        ELSE '❌'
    END as has_approved_check,
    CASE
        WHEN u.operation_start_date IS NOT NULL THEN '✅'
        ELSE '❌ NULL'
    END as operation_start_not_null,
    CASE
        WHEN u.operation_start_date <= '2025-11-26' THEN '✅'
        WHEN u.operation_start_date > '2025-11-26' THEN '❌ 未来'
        ELSE '❌ NULL'
    END as operation_start_check,
    CASE
        WHEN u.referrer_user_id IS NOT NULL THEN '✅'
        ELSE '❌ NULL'
    END as has_referrer,
    CASE
        WHEN u.has_approved_nft = true
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= '2025-11-26'
          AND u.referrer_user_id IS NOT NULL
          THEN '✅ 対象'
        ELSE '❌ 対象外'
    END as step3_eligible
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.user_id = '039483'
GROUP BY u.user_id, u.has_approved_nft, u.operation_start_date, u.referrer_user_id, nm.buyback_date;

-- 7. 親ユーザーの情報
SELECT '=== 7. 親ユーザーの情報 ===' as section;

WITH parent_ids AS (
    SELECT DISTINCT user_id as parent_id
    FROM user_referral_profit
    WHERE child_user_id = '039483'
      AND date = '2025-11-26'
)
SELECT
    u.user_id,
    u.email,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN '未設定'
        WHEN u.operation_start_date > '2025-11-26' THEN '未開始'
        ELSE '開始済み'
    END as operation_status,
    (
        SELECT COUNT(*)
        FROM nft_master nm
        WHERE nm.user_id = u.user_id
          AND nm.buyback_date IS NULL
    ) as nft_count
FROM parent_ids p
INNER JOIN users u ON p.parent_id = u.user_id;

-- サマリー
DO $$
DECLARE
    v_user_id VARCHAR(10) := '039483';
    v_has_approved BOOLEAN;
    v_operation_start DATE;
    v_nft_count INTEGER;
    v_daily_profit NUMERIC;
    v_referral_total NUMERIC;
BEGIN
    SELECT
        has_approved_nft,
        operation_start_date
    INTO v_has_approved, v_operation_start
    FROM users
    WHERE user_id = v_user_id;

    SELECT COUNT(*)
    INTO v_nft_count
    FROM nft_master
    WHERE user_id = v_user_id
      AND buyback_date IS NULL;

    SELECT daily_profit
    INTO v_daily_profit
    FROM user_daily_profit
    WHERE user_id = v_user_id
      AND date = '2025-11-26';

    SELECT SUM(profit_amount)
    INTO v_referral_total
    FROM user_referral_profit
    WHERE child_user_id = v_user_id
      AND date = '2025-11-26';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '🔍 ユーザー039483の分析';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'has_approved_nft: %', v_has_approved;
    RAISE NOTICE 'operation_start_date: %', v_operation_start;
    RAISE NOTICE 'NFT数: %個', v_nft_count;
    RAISE NOTICE '';
    RAISE NOTICE '11/26の状況:';
    RAISE NOTICE '  個人日利: $%', COALESCE(v_daily_profit, 0);
    RAISE NOTICE '  親への紹介報酬合計: $%', COALESCE(v_referral_total, 0);
    RAISE NOTICE '';
    IF v_operation_start IS NULL THEN
        RAISE NOTICE '❌ 運用開始日が未設定';
        RAISE NOTICE '  → STEP 3のチェックで弾かれるはず';
        RAISE NOTICE '  → なぜ紹介報酬が発生？';
    ELSIF v_operation_start > '2025-11-26' THEN
        RAISE NOTICE '❌ 運用開始前（%）', v_operation_start;
        RAISE NOTICE '  → STEP 3のチェックで弾かれるはず';
        RAISE NOTICE '  → なぜ紹介報酬が発生？';
    ELSE
        RAISE NOTICE '✅ 運用開始済み（%）', v_operation_start;
        IF v_daily_profit IS NULL OR v_daily_profit = 0 THEN
            RAISE NOTICE '❌ でも日利レコードなし/0円';
            RAISE NOTICE '  → なぜ？';
        END IF;
    END IF;
    RAISE NOTICE '===========================================';
END $$;
