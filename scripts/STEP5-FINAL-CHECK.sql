-- ========================================
-- STEP 5-4: 削除後の最終確認
-- ========================================

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

-- バックアップとの比較
SELECT
    '📊 バックアップとの比較' as label,
    (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit) as backup_count,
    (SELECT COUNT(*) FROM nft_daily_profit) as current_count,
    (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit) - (SELECT COUNT(*) FROM nft_daily_profit) as deleted_records,
    CASE
        WHEN (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit) - (SELECT COUNT(*) FROM nft_daily_profit) = 839
        THEN '✅ 正確に839件削除されました'
        ELSE '⚠️ 削除件数が想定と異なります'
    END as validation;

-- ========================================
-- 完了メッセージ
-- ========================================
SELECT
    '✅✅✅ 緊急修正手順が完了しました ✅✅✅' as status,
    'システムを再開しても問題ありません' as next_action;

-- ========================================
-- 重要: すべてのステータスが「✅」であることを確認してください
-- ========================================
