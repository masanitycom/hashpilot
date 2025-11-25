-- ========================================
-- STEP 5: 誤配布データの削除
-- ========================================
-- ⚠️⚠️⚠️ この操作は取り消せません ⚠️⚠️⚠️
-- 実行前に必ずバックアップを確認してください
-- ========================================

-- ========================================
-- STEP 5-1: 削除前の最終確認
-- ========================================

-- 削除対象のレコード数を確認
SELECT
    '🗑️ 削除対象: nft_daily_profit' as table_name,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date;

SELECT
    '🗑️ 削除対象: user_referral_profit' as table_name,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit
FROM user_referral_profit urp
JOIN users u ON urp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > urp.date;

-- ========================================
-- STEP 5-2: affiliate_cycleの調整額を確認
-- ========================================

-- ユーザーごとの調整額を確認（上位20件）
SELECT
    '💰 affiliate_cycle調整対象（上位20件）' as label,
    COALESCE(ndp_summary.user_id, urp_summary.user_id) as user_id,
    u.full_name,
    u.operation_start_date,
    COALESCE(ndp_summary.total_personal, 0) as personal_to_deduct,
    COALESCE(urp_summary.total_referral, 0) as referral_to_deduct,
    ac.cum_usdt as current_cum_usdt,
    ac.available_usdt as current_available_usdt,
    ac.cum_usdt - COALESCE(urp_summary.total_referral, 0) as new_cum_usdt,
    ac.available_usdt - COALESCE(ndp_summary.total_personal, 0) as new_available_usdt,
    ac.phase as current_phase,
    CASE
        WHEN (ac.cum_usdt - COALESCE(urp_summary.total_referral, 0)) >= 1100 THEN 'HOLD'
        ELSE 'USDT'
    END as new_phase
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
ORDER BY (COALESCE(ndp_summary.total_personal, 0) + COALESCE(urp_summary.total_referral, 0)) DESC
LIMIT 20;

-- ========================================
-- STEP 5-3: 実際の削除とaffiliate_cycleの調整
-- ========================================
-- ⚠️⚠️⚠️ この下のコメントを外して実行してください ⚠️⚠️⚠️
-- ⚠️ 実行前に必ずバックアップを確認してください ⚠️
-- ⚠️ STEP 5-1とSTEP 5-2の結果を確認してください ⚠️
-- ========================================

/*
BEGIN;

-- ========================================
-- 5-3-1. affiliate_cycleの調整（個人利益分）
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

SELECT '✅ affiliate_cycle（個人利益分）調整完了' as status;

-- ========================================
-- 5-3-2. affiliate_cycleの調整（紹介報酬分）
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

SELECT '✅ affiliate_cycle（紹介報酬分）調整完了' as status;

-- ========================================
-- 5-3-3. nft_daily_profitの削除
-- ========================================

DELETE FROM nft_daily_profit
WHERE id IN (
    SELECT ndp.id
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
);

SELECT '✅ nft_daily_profit削除完了' as status;

-- ========================================
-- 5-3-4. user_referral_profitの削除
-- ========================================

DELETE FROM user_referral_profit
WHERE id IN (
    SELECT urp.id
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
);

SELECT '✅ user_referral_profit削除完了' as status;

-- ========================================
-- 5-3-5. 削除完了確認
-- ========================================

SELECT
    '✅ 削除完了確認' as status,
    (SELECT COUNT(*) FROM nft_daily_profit ndp JOIN users u ON ndp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) as remaining_ndp,
    (SELECT COUNT(*) FROM user_referral_profit urp JOIN users u ON urp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) as remaining_urp,
    CASE
        WHEN (SELECT COUNT(*) FROM nft_daily_profit ndp JOIN users u ON ndp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) = 0
         AND (SELECT COUNT(*) FROM user_referral_profit urp JOIN users u ON urp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) = 0
        THEN '✅ すべて削除されました'
        ELSE '❌ まだレコードが残っています'
    END as deletion_status;

-- ========================================
-- 問題がなければコミット、問題があればロールバック
-- ========================================

-- 上記の結果を確認して、すべて正しければ以下のCOMMITを実行
-- COMMIT;

-- 問題があれば以下のROLLBACKを実行
ROLLBACK; -- 安全のため、デフォルトはROLLBACK

*/

-- ========================================
-- STEP 5-4: 削除後の確認クエリ
-- ========================================
-- 実行後に以下のクエリで確認してください

SELECT
    '✅ 削除後の最終確認' as label,
    (SELECT COUNT(*) FROM nft_daily_profit ndp JOIN users u ON ndp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) as remaining_incorrect_ndp,
    (SELECT COUNT(*) FROM user_referral_profit urp JOIN users u ON urp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) as remaining_incorrect_urp,
    CASE
        WHEN (SELECT COUNT(*) FROM nft_daily_profit ndp JOIN users u ON ndp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) = 0
         AND (SELECT COUNT(*) FROM user_referral_profit urp JOIN users u ON urp.user_id = u.user_id WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) = 0
        THEN '✅✅✅ すべての誤配布データが削除されました ✅✅✅'
        ELSE '❌ まだ問題が残っています。再度確認してください。'
    END as final_status;

-- ========================================
-- 全体のデータ整合性確認
-- ========================================

-- 運用中のユーザーの確認
SELECT
    '📊 運用中のユーザー（最終確認）' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft
FROM users u
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_approved = true
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= CURRENT_DATE;

-- affiliate_cycleの整合性確認
SELECT
    '💰 affiliate_cycle整合性確認' as label,
    COUNT(*) as total_users,
    SUM(CASE WHEN cum_usdt < 0 THEN 1 ELSE 0 END) as negative_cum_usdt_count,
    SUM(CASE WHEN available_usdt < 0 THEN 1 ELSE 0 END) as negative_available_usdt_count,
    CASE
        WHEN SUM(CASE WHEN cum_usdt < 0 OR available_usdt < 0 THEN 1 ELSE 0 END) = 0
        THEN '✅ 問題なし'
        ELSE '⚠️ マイナス残高のユーザーが存在します'
    END as status
FROM affiliate_cycle;

-- ========================================
-- 完了メッセージ
-- ========================================
SELECT
    '✅✅✅ 緊急修正手順が完了しました ✅✅✅' as status,
    'システムを再開しても問題ありません' as next_action;

-- ========================================
-- 重要: すべてのステータスが「✅」であることを確認してください
-- マイナス残高がある場合は、個別に調査が必要です
-- ========================================
