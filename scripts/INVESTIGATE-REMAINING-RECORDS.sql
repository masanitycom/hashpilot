-- ========================================
-- 残っている誤配布レコードの調査
-- ========================================

-- ========================================
-- 1. 残っているレコードの詳細（サンプル20件）
-- ========================================

SELECT
    '🔍 残っているnft_daily_profitレコード（サンプル20件）' as label,
    ndp.id,
    ndp.user_id,
    u.full_name,
    ndp.date,
    ndp.daily_profit,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN 'operation_start_date = NULL'
        WHEN u.operation_start_date > ndp.date THEN 'operation_start_date > date'
        ELSE '条件に該当しない'
    END as reason,
    u.has_approved_nft
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date
ORDER BY ndp.date DESC, ndp.user_id
LIMIT 20;

-- ========================================
-- 2. 削除条件の確認
-- ========================================

-- operation_start_date IS NULL のユーザー
SELECT
    '📊 operation_start_date = NULL のユーザー' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(ndp.id) as ndp_record_count,
    SUM(ndp.daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL;

-- operation_start_date > ndp.date のユーザー
SELECT
    '📊 operation_start_date > date のユーザー' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(ndp.id) as ndp_record_count,
    SUM(ndp.daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NOT NULL
    AND u.operation_start_date > ndp.date;

-- ========================================
-- 3. STEP4で修正したはずのユーザーを確認
-- ========================================

-- has_approved_nft = false のユーザーがまだいるか確認
SELECT
    '🚨 has_approved_nft = false のユーザー確認' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(ndp.id) as ndp_record_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.has_approved_nft = false
    AND (u.operation_start_date IS NULL OR u.operation_start_date > ndp.date);

-- ========================================
-- 4. トランザクションの確認
-- ========================================

-- STEP5で削除したはずのレコード数を確認
SELECT
    '🔍 STEP5実行前後の比較' as label,
    '実行前: 853件' as expected_before,
    '実行後（現在）: ' || COUNT(*)::TEXT || '件' as current_count,
    '削除されたはず: ' || (853 - COUNT(*))::TEXT || '件' as deleted_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date;

-- ========================================
-- 5. 削除対象IDリストの生成（確認用）
-- ========================================

-- 削除対象のIDをリストアップ（最初の50件）
SELECT
    '🗑️ 削除対象ID（最初の50件）' as label,
    ndp.id,
    ndp.user_id,
    ndp.date,
    u.operation_start_date
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date
ORDER BY ndp.id
LIMIT 50;

-- ========================================
-- 6. 削除が実行されたか確認
-- ========================================

-- バックアップとの件数比較
SELECT
    '📊 バックアップとの比較' as label,
    (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit) as backup_count,
    (SELECT COUNT(*) FROM nft_daily_profit) as current_count,
    (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit) - (SELECT COUNT(*) FROM nft_daily_profit) as deleted_records,
    CASE
        WHEN (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit) = (SELECT COUNT(*) FROM nft_daily_profit)
        THEN '⚠️ レコード数が同じ = 削除が実行されていない可能性'
        ELSE '✅ レコード数が減少 = 削除が実行された'
    END as status;

-- ========================================
-- 完了メッセージ
-- ========================================

SELECT '調査完了: 上記の結果を確認してください' as message;
