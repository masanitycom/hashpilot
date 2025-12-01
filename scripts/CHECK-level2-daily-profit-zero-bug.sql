-- ========================================
-- Level 2紹介報酬バグの詳細調査
-- 子ユーザーの日利が$0なのに紹介報酬が記録されている問題
-- ========================================

-- 問題の特定:
-- 11/26のデータで、以下のユーザーが異常な報酬を受け取っている:
-- - 039483: 日利$0 なのに $0.798の報酬
-- - 1DEFED: 日利$0 なのに $0.798の報酬
-- - 2D378C: 日利$0 なのに $0.798の報酬
-- - 6FF2D1: 日利$0 なのに $0.798の報酬

-- 1. 11月全体で「日利$0だが紹介報酬あり」のレコード確認
SELECT '=== 1. 日利$0だが紹介報酬ありのレコード ===' as section;

WITH child_daily AS (
    SELECT
        urp.user_id as parent_user_id,
        urp.child_user_id,
        urp.date,
        urp.referral_level,
        urp.profit_amount as recorded_profit,
        COALESCE(udp.daily_profit, 0) as child_daily_profit
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
)
SELECT
    referral_level,
    COUNT(*) as record_count,
    SUM(recorded_profit) as total_incorrect_profit,
    COUNT(DISTINCT parent_user_id) as affected_parents,
    COUNT(DISTINCT child_user_id) as affected_children
FROM child_daily
WHERE child_daily_profit = 0 AND recorded_profit > 0
GROUP BY referral_level
ORDER BY referral_level;

-- 2. 具体例（11/26のユーザー039483など）
SELECT '=== 2. 具体例: 11/26の日利$0ユーザー ===' as section;

WITH child_daily AS (
    SELECT
        urp.user_id as parent_user_id,
        urp.child_user_id,
        u.email,
        urp.date,
        urp.referral_level,
        urp.profit_amount as recorded_profit,
        COALESCE(udp.daily_profit, 0) as child_daily_profit,
        (
            SELECT operation_start_date
            FROM users
            WHERE user_id = urp.child_user_id
        ) as child_operation_start
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    LEFT JOIN users u ON urp.child_user_id = u.user_id
    WHERE urp.date = '2025-11-26'
      AND urp.user_id = '177B83'
      AND urp.referral_level = 2
)
SELECT
    child_user_id,
    email,
    child_operation_start,
    child_daily_profit,
    recorded_profit,
    CASE
        WHEN child_operation_start IS NULL THEN '未設定'
        WHEN child_operation_start > date THEN '未開始'
        ELSE '開始済み'
    END as operation_status
FROM child_daily
WHERE child_daily_profit = 0 AND recorded_profit > 0
ORDER BY recorded_profit DESC;

-- 3. 日利$0ユーザーのNFT状況確認
SELECT '=== 3. 日利$0ユーザーのNFT状況 ===' as section;

WITH zero_profit_users AS (
    SELECT DISTINCT urp.child_user_id
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND COALESCE(udp.daily_profit, 0) = 0
      AND urp.profit_amount > 0
)
SELECT
    zpu.child_user_id,
    u.email,
    u.operation_start_date,
    COUNT(nm.id) as nft_count,
    (
        SELECT COUNT(*)
        FROM user_daily_profit udp
        WHERE udp.user_id = zpu.child_user_id
          AND udp.date >= '2025-11-01'
          AND udp.date <= '2025-11-30'
    ) as daily_profit_records,
    (
        SELECT SUM(profit_amount)
        FROM user_referral_profit urp
        WHERE urp.child_user_id = zpu.child_user_id
          AND urp.date >= '2025-11-01'
          AND urp.date <= '2025-11-30'
    ) as total_profit_to_parents
FROM zero_profit_users zpu
INNER JOIN users u ON zpu.child_user_id = u.user_id
LEFT JOIN nft_master nm ON zpu.child_user_id = nm.user_id AND nm.buyback_date IS NULL
GROUP BY zpu.child_user_id, u.email, u.operation_start_date
ORDER BY nft_count DESC;

-- 4. 全システムの誤配布額を計算
SELECT '=== 4. 全システムの誤配布額（11月） ===' as section;

WITH child_daily AS (
    SELECT
        urp.user_id as parent_user_id,
        urp.child_user_id,
        urp.date,
        urp.referral_level,
        urp.profit_amount as recorded_profit,
        COALESCE(udp.daily_profit, 0) as child_daily_profit
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
)
SELECT
    SUM(recorded_profit) as total_incorrect_distribution,
    COUNT(*) as total_incorrect_records,
    COUNT(DISTINCT parent_user_id) as affected_parents,
    COUNT(DISTINCT child_user_id) as affected_children,
    COUNT(DISTINCT date) as affected_dates
FROM child_daily
WHERE child_daily_profit = 0 AND recorded_profit > 0;

-- 5. $0.798の謎の金額の由来を調査
SELECT '=== 5. $0.798の謎の金額の由来 ===' as section;

-- $0.798 = 1 NFT × $7.98（11/26の1 NFT日利） × 10%（Level 2）
-- つまり、子ユーザーの運用開始前なのに、「もし開始していたら」の金額で計算されている可能性

WITH mystery_amount AS (
    SELECT
        urp.child_user_id,
        urp.date,
        urp.profit_amount,
        COUNT(nm.id) as nft_count,
        u.operation_start_date
    FROM user_referral_profit urp
    INNER JOIN users u ON urp.child_user_id = u.user_id
    LEFT JOIN nft_master nm ON urp.child_user_id = nm.user_id AND nm.buyback_date IS NULL
    WHERE urp.profit_amount = 0.798
      AND urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
    GROUP BY urp.child_user_id, urp.date, urp.profit_amount, u.operation_start_date
)
SELECT
    child_user_id,
    date,
    profit_amount,
    nft_count,
    operation_start_date,
    CASE
        WHEN operation_start_date IS NULL THEN '未設定'
        WHEN operation_start_date > date THEN '未開始（運用開始前）'
        ELSE '開始済み'
    END as status,
    (nft_count * 7.98 * 0.10) as expected_if_operating
FROM mystery_amount
ORDER BY date DESC, child_user_id
LIMIT 20;

-- サマリー
DO $$
DECLARE
    v_total_incorrect NUMERIC;
    v_incorrect_records INTEGER;
    v_affected_parents INTEGER;
    v_affected_children INTEGER;
BEGIN
    WITH child_daily AS (
        SELECT
            urp.user_id as parent_user_id,
            urp.child_user_id,
            urp.profit_amount as recorded_profit,
            COALESCE(udp.daily_profit, 0) as child_daily_profit
        FROM user_referral_profit urp
        LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
        WHERE urp.date >= '2025-11-01'
          AND urp.date <= '2025-11-30'
    )
    SELECT
        SUM(recorded_profit),
        COUNT(*),
        COUNT(DISTINCT parent_user_id),
        COUNT(DISTINCT child_user_id)
    INTO v_total_incorrect, v_incorrect_records, v_affected_parents, v_affected_children
    FROM child_daily
    WHERE child_daily_profit = 0 AND recorded_profit > 0;

    RAISE NOTICE '===========================================';
    RAISE NOTICE '🚨 Level 2紹介報酬バグの分析結果';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '問題: 子ユーザーの日利が$0なのに紹介報酬が記録されている';
    RAISE NOTICE '';
    RAISE NOTICE '誤配布額: $%', v_total_incorrect;
    RAISE NOTICE '誤配布レコード数: %', v_incorrect_records;
    RAISE NOTICE '影響を受けた親ユーザー数: %', v_affected_parents;
    RAISE NOTICE '影響を受けた子ユーザー数: %', v_affected_children;
    RAISE NOTICE '';
    RAISE NOTICE '原因の仮説:';
    RAISE NOTICE '  V1関数が子ユーザーのoperation_start_dateをチェックせず、';
    RAISE NOTICE '  NFT数から計算した「仮想日利」で紹介報酬を計算している';
    RAISE NOTICE '===========================================';
END $$;
