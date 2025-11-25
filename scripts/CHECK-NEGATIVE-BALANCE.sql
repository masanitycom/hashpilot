-- ========================================
-- マイナス残高ユーザーの調査
-- ========================================

-- ========================================
-- 1. マイナス残高の概要
-- ========================================

SELECT
    '📊 マイナス残高の概要' as label,
    COUNT(*) as total_negative_users,
    SUM(CASE WHEN available_usdt < 0 THEN 1 ELSE 0 END) as negative_available,
    SUM(CASE WHEN cum_usdt < 0 THEN 1 ELSE 0 END) as negative_cum,
    MIN(available_usdt) as min_available_usdt,
    MAX(available_usdt) as max_available_usdt,
    AVG(available_usdt) as avg_available_usdt
FROM affiliate_cycle
WHERE available_usdt < 0 OR cum_usdt < 0;

-- ========================================
-- 2. マイナス残高ユーザーの詳細（上位20件）
-- ========================================

SELECT
    '👤 マイナス残高ユーザー詳細（上位20件）' as label,
    ac.user_id,
    u.full_name,
    u.operation_start_date,
    ac.available_usdt,
    ac.cum_usdt,
    ac.phase,
    COUNT(DISTINCT nm.id) as nft_count,
    SUM(p.amount_usd) as total_purchases
FROM affiliate_cycle ac
LEFT JOIN users u ON ac.user_id = u.user_id
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN purchases p ON ac.user_id = p.user_id AND p.admin_approved = true
WHERE ac.available_usdt < 0
GROUP BY ac.user_id, u.full_name, u.operation_start_date, ac.available_usdt, ac.cum_usdt, ac.phase
ORDER BY ac.available_usdt ASC
LIMIT 20;

-- ========================================
-- 3. 今回削除したユーザーとの重複確認
-- ========================================

-- 今回削除対象だった55ユーザーのうち、マイナス残高は何人？
SELECT
    '🔍 削除対象ユーザーとマイナス残高の重複' as label,
    COUNT(DISTINCT ac.user_id) as negative_users_from_deleted_group,
    SUM(ac.available_usdt) as total_negative_amount
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE ac.available_usdt < 0
    AND (u.operation_start_date IS NULL OR u.operation_start_date > CURRENT_DATE);

-- ========================================
-- 4. バックアップとの比較
-- ========================================

-- バックアップ時点のマイナス残高ユーザー数
SELECT
    '📊 バックアップとの比較' as label,
    (SELECT COUNT(*) FROM backup_20251115.affiliate_cycle WHERE available_usdt < 0) as backup_negative_count,
    (SELECT COUNT(*) FROM affiliate_cycle WHERE available_usdt < 0) as current_negative_count,
    (SELECT COUNT(*) FROM affiliate_cycle WHERE available_usdt < 0) -
    (SELECT COUNT(*) FROM backup_20251115.affiliate_cycle WHERE available_usdt < 0) as difference,
    CASE
        WHEN (SELECT COUNT(*) FROM affiliate_cycle WHERE available_usdt < 0) =
             (SELECT COUNT(*) FROM backup_20251115.affiliate_cycle WHERE available_usdt < 0)
        THEN '✅ マイナス残高数は変わっていない（元々存在していた問題）'
        ELSE '⚠️ 今回の修正でマイナス残高が発生した可能性'
    END as analysis;

SELECT '調査完了' as status;
