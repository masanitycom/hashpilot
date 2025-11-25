-- ========================================
-- STEP 5-3: 実際の削除処理（コメント除去版）
-- ========================================
-- ⚠️⚠️⚠️ この操作は取り消せません ⚠️⚠️⚠️
-- ⚠️ 実行前に必ずバックアップを確認してください ⚠️
-- ⚠️ STEP 5-1とSTEP 5-2の結果を確認してください ⚠️
-- ========================================

BEGIN;

-- ========================================
-- 5-3-1. nft_daily_profitの削除
-- ========================================

DELETE FROM nft_daily_profit
WHERE id IN (
    SELECT ndp.id
    FROM nft_daily_profit ndp
    JOIN users u ON ndp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > ndp.date
);

SELECT '✅ nft_daily_profit削除完了' as status,
       (SELECT COUNT(*)
        FROM nft_daily_profit ndp
        JOIN users u ON ndp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL OR u.operation_start_date > ndp.date) as remaining_records;

-- ========================================
-- 5-3-2. user_referral_profitの削除
-- ========================================

DELETE FROM user_referral_profit
WHERE id IN (
    SELECT urp.id
    FROM user_referral_profit urp
    JOIN users u ON urp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
        OR u.operation_start_date > urp.date
);

SELECT '✅ user_referral_profit削除完了' as status,
       (SELECT COUNT(*)
        FROM user_referral_profit urp
        JOIN users u ON urp.user_id = u.user_id
        WHERE u.operation_start_date IS NULL OR u.operation_start_date > urp.date) as remaining_records;

-- ========================================
-- 5-3-3. 削除完了確認
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
