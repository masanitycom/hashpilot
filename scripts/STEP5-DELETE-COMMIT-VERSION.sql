-- ========================================
-- STEP 5: 削除処理（COMMIT確定版）
-- ========================================
-- ⚠️⚠️⚠️ この操作は取り消せません ⚠️⚠️⚠️
-- ⚠️ 必ず全体を選択して実行してください ⚠️
-- ========================================

BEGIN;

-- ========================================
-- nft_daily_profitの削除（839件）
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
-- user_referral_profitの削除（0件）
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
-- 削除完了確認
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
-- ⚠️⚠️⚠️ 削除を確定します ⚠️⚠️⚠️
-- ========================================

COMMIT;

SELECT '🎉🎉🎉 削除がデータベースに確定されました 🎉🎉🎉' as final_message;
