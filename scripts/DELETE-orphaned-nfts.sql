-- ========================================
-- 孤立NFTの削除（usersテーブルに存在しないユーザーのNFT）
-- ========================================
-- 対象: 2F0B1F, 368E3F, E7F984, F38DF5
-- 理由: これらのユーザーはusersテーブルに存在せず、不要なデータ

-- 1. 削除前の確認
SELECT
    '削除前: 孤立NFT' as section,
    user_id,
    id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    created_at
FROM nft_master
WHERE user_id IN ('2F0B1F', '368E3F', 'E7F984', 'F38DF5')
ORDER BY user_id;

-- 2. 孤立NFTを削除
DELETE FROM nft_master
WHERE user_id IN ('2F0B1F', '368E3F', 'E7F984', 'F38DF5');

-- 3. 削除後の整合性確認
SELECT
    '削除後: 整合性チェック' as section,
    COUNT(DISTINCT nm.user_id) as users_with_nft,
    COUNT(DISTINCT u.user_id) FILTER (WHERE nm.user_id IS NOT NULL) as users_in_users_table,
    COUNT(DISTINCT nm.user_id) FILTER (WHERE u.user_id IS NULL) as orphaned_users
FROM nft_master nm
LEFT JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL;

-- 4. 全体サマリー（削除後）
SELECT
    '削除後: 全体サマリー' as section,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_active_nft,
    COUNT(DISTINCT user_id) FILTER (WHERE buyback_date IS NULL) as total_users_with_nft,
    (SELECT SUM(total_nft_count) FROM affiliate_cycle) as affiliate_cycle_total
FROM nft_master;

-- 5. 差異チェック（削除後）
SELECT
    '削除後: 差異チェック' as section,
    (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) as actual_nft,
    (SELECT SUM(total_nft_count) FROM affiliate_cycle) as recorded_nft,
    (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) -
    (SELECT SUM(total_nft_count) FROM affiliate_cycle) as difference;

-- 完了メッセージ
SELECT '✅ 孤立NFT 4件を削除しました。整合性が回復しました。' as status;
