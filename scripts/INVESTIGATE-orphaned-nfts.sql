-- ========================================
-- 孤立NFTの調査（usersテーブルに存在しないユーザーのNFT）
-- ========================================

-- 1. NFTは存在するがusersテーブルに存在しないユーザー
SELECT
    '1. 孤立NFT（usersテーブルに存在しない）' as section,
    nm.user_id,
    COUNT(*) as nft_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual') as manual_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto') as auto_count,
    MIN(nm.created_at) as first_created,
    MAX(nm.created_at) as last_created
FROM nft_master nm
LEFT JOIN users u ON nm.user_id = u.user_id
WHERE u.user_id IS NULL
  AND nm.buyback_date IS NULL
GROUP BY nm.user_id
ORDER BY nm.user_id;

-- 2. これらのユーザーのNFT詳細
SELECT
    '2. 孤立NFTの詳細' as section,
    nm.id,
    nm.user_id,
    nm.nft_sequence,
    nm.nft_type,
    nm.nft_value,
    nm.acquired_date,
    nm.created_at,
    u.user_id as users_exists
FROM nft_master nm
LEFT JOIN users u ON nm.user_id = u.user_id
WHERE u.user_id IS NULL
  AND nm.buyback_date IS NULL
ORDER BY nm.user_id, nm.nft_sequence;

-- 3. これらのユーザーのpurchasesレコードがあるか
SELECT
    '3. 孤立NFTに関連する購入レコード' as section,
    p.id as purchase_id,
    p.user_id,
    p.nft_quantity,
    p.amount_usd,
    p.admin_approved,
    p.admin_approved_at,
    p.created_at,
    u.user_id as users_exists
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE p.user_id IN ('2F0B1F', '368E3F', 'E7F984', 'F38DF5')
ORDER BY p.user_id, p.created_at;

-- 4. 全体のusersテーブルとnft_masterの整合性チェック
SELECT
    '4. usersテーブルとnft_masterの整合性' as section,
    COUNT(DISTINCT nm.user_id) as users_with_nft,
    COUNT(DISTINCT u.user_id) FILTER (WHERE nm.user_id IS NOT NULL) as users_in_users_table,
    COUNT(DISTINCT nm.user_id) FILTER (WHERE u.user_id IS NULL) as orphaned_users
FROM nft_master nm
LEFT JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL;

-- 5. 解決策の提案
SELECT
    '5. 解決策' as section,
    '以下のいずれかの対応が必要です：' as recommendation
UNION ALL
SELECT
    '',
    'A) これらのNFTを削除する（データクリーニング）'
UNION ALL
SELECT
    '',
    'B) これらのユーザーをusersテーブルに作成する'
UNION ALL
SELECT
    '',
    'C) NFTを既存の有効なユーザーに移動する';

-- 完了メッセージ
SELECT '✅ 孤立NFT調査完了。上記の結果を確認してください。' as status;
