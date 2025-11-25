-- ========================================
-- 【注意】誤配布された利益データの削除
-- ========================================
-- このスクリプトは慎重に実行してください
-- 実行前に必ずバックアップを取ってください
-- ========================================

-- ========================================
-- STEP 1: 削除前の確認（必ず実行）
-- ========================================

-- 削除対象のレコード数を確認
SELECT
    'nft_daily_profit削除対象' as table_name,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date;

SELECT
    'user_referral_profit削除対象' as table_name,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit
FROM user_referral_profit urp
JOIN users u ON urp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > urp.date;

-- ========================================
-- STEP 2: affiliate_cycleの調整額を計算
-- ========================================

-- ユーザーごとの調整額を確認
SELECT
    'affiliate_cycle調整対象' as label,
    COALESCE(ndp_summary.user_id, urp_summary.user_id) as user_id,
    u.full_name,
    u.operation_start_date,
    COALESCE(ndp_summary.total_personal, 0) as personal_to_deduct,
    COALESCE(urp_summary.total_referral, 0) as referral_to_deduct,
    ac.cum_usdt as current_cum_usdt,
    ac.available_usdt as current_available_usdt,
    ac.cum_usdt - COALESCE(urp_summary.total_referral, 0) as new_cum_usdt,
    ac.available_usdt - COALESCE(ndp_summary.total_personal, 0) as new_available_usdt
FROM (
    SELECT
        ndp.user_id,
        SUM(ndp.daily_profit) as total_personal
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
    GROUP BY ndp.user_id
) ndp_summary
FULL OUTER JOIN (
    SELECT
        urp.user_id,
        SUM(urp.profit_amount) as total_referral
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
    GROUP BY urp.user_id
) urp_summary ON ndp_summary.user_id = urp_summary.user_id
JOIN users u ON COALESCE(ndp_summary.user_id, urp_summary.user_id) = u.user_id
LEFT JOIN affiliate_cycle ac ON COALESCE(ndp_summary.user_id, urp_summary.user_id) = ac.user_id
ORDER BY (COALESCE(ndp_summary.total_personal, 0) + COALESCE(urp_summary.total_referral, 0)) DESC;

-- ========================================
-- STEP 3: 実際の削除とaffiliate_cycleの調整
-- ========================================
-- ⚠️ この下のコメントを外して実行する前に、必ずバックアップを取ってください
-- ⚠️ STEP 1とSTEP 2の結果を確認してから実行してください
-- ========================================

/*
BEGIN;

-- ========================================
-- 3-1. affiliate_cycleの調整（個人利益分）
-- ========================================

-- 個人利益の誤配布分をavailable_usdtから差し引く
UPDATE affiliate_cycle ac
SET
    available_usdt = available_usdt - ndp_summary.total_personal,
    updated_at = NOW()
FROM (
    SELECT
        ndp.user_id,
        SUM(ndp.daily_profit) as total_personal
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
    GROUP BY ndp.user_id
) ndp_summary
WHERE ac.user_id = ndp_summary.user_id;

-- ========================================
-- 3-2. affiliate_cycleの調整（紹介報酬分）
-- ========================================

-- 紹介報酬の誤配布分をcum_usdtから差し引く
UPDATE affiliate_cycle ac
SET
    cum_usdt = cum_usdt - urp_summary.total_referral,
    phase = CASE
        WHEN (cum_usdt - urp_summary.total_referral) >= 1100 THEN 'HOLD'
        ELSE 'USDT'
    END,
    updated_at = NOW()
FROM (
    SELECT
        urp.user_id,
        SUM(urp.profit_amount) as total_referral
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
    GROUP BY urp.user_id
) urp_summary
WHERE ac.user_id = urp_summary.user_id;

-- ========================================
-- 3-3. nft_daily_profitの削除
-- ========================================

DELETE FROM nft_daily_profit
WHERE id IN (
    SELECT ndp.id
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
);

-- ========================================
-- 3-4. user_referral_profitの削除
-- ========================================

DELETE FROM user_referral_profit
WHERE id IN (
    SELECT urp.id
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
);

-- ========================================
-- 削除完了確認
-- ========================================

SELECT
    '削除完了' as status,
    (SELECT COUNT(*) FROM nft_daily_profit ndp JOIN users u ON ndp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) as remaining_ndp,
    (SELECT COUNT(*) FROM user_referral_profit urp JOIN users u ON urp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) as remaining_urp;

-- 問題がなければコミット、問題があればロールバック
-- COMMIT;
ROLLBACK; -- 安全のため、デフォルトはROLLBACK

*/

-- ========================================
-- 実行後の確認クエリ
-- ========================================

-- 実行後に以下のクエリで確認してください
/*
SELECT
    '削除後の確認' as label,
    (SELECT COUNT(*) FROM nft_daily_profit ndp JOIN users u ON ndp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) as remaining_incorrect_ndp,
    (SELECT COUNT(*) FROM user_referral_profit urp JOIN users u ON urp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) as remaining_incorrect_urp;
*/
