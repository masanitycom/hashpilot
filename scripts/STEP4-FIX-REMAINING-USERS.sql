-- ========================================
-- STEP 4-追加: 残りの55ユーザーのフラグ修正
-- ========================================
-- operation_start_dateが設定されているのに
-- has_approved_nft = false のユーザーを修正
-- ========================================

-- ========================================
-- 確認: 修正対象ユーザー
-- ========================================

SELECT
    '🚨 修正対象ユーザー確認' as label,
    COUNT(DISTINCT user_id) as user_count,
    STRING_AGG(DISTINCT user_id, ', ' ORDER BY user_id) as user_ids
FROM users
WHERE operation_start_date IS NOT NULL
    AND has_approved_nft = false;

-- 詳細リスト（全件）
SELECT
    '👤 修正対象ユーザー詳細' as label,
    user_id,
    full_name,
    has_approved_nft,
    operation_start_date,
    created_at
FROM users
WHERE operation_start_date IS NOT NULL
    AND has_approved_nft = false
ORDER BY operation_start_date, user_id;

-- ========================================
-- 修正実行
-- ========================================

BEGIN;

-- operation_start_dateが設定されているユーザーは必ずhas_approved_nft = trueであるべき
UPDATE users
SET
    has_approved_nft = true,
    updated_at = NOW()
WHERE operation_start_date IS NOT NULL
    AND has_approved_nft = false;

-- 更新結果確認
SELECT
    '✅ has_approved_nft更新完了' as status,
    (SELECT COUNT(*) FROM users WHERE operation_start_date IS NOT NULL AND has_approved_nft = true) as total_approved,
    (SELECT COUNT(*) FROM users WHERE operation_start_date IS NOT NULL AND has_approved_nft = false) as remaining_issues,
    CASE
        WHEN (SELECT COUNT(*) FROM users WHERE operation_start_date IS NOT NULL AND has_approved_nft = false) = 0
        THEN '✅ 問題なし'
        ELSE '❌ まだ問題が残っています'
    END as result;

COMMIT;

-- ========================================
-- 最終確認
-- ========================================

-- 削除対象レコードの再確認
SELECT
    '📊 削除対象レコード（修正後）' as label,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date;

-- has_approved_nft = false のユーザーが残っているか確認
SELECT
    '🔍 has_approved_nft = false 確認' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(ndp.id) as ndp_record_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.has_approved_nft = false
    AND (u.operation_start_date IS NULL OR u.operation_start_date > ndp.date);

SELECT '✅ STEP4追加修正完了' as status;
