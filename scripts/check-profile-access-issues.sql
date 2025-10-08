-- プロフィールアクセスできないユーザーを確認

SELECT '=== NFTを持っているのに has_approved_nft=false のユーザー ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.total_nft_count,
    u.created_at
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.total_nft_count > 0
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL)
ORDER BY u.created_at DESC;

SELECT '=== 集計 ===' as section;

SELECT
    COUNT(*) as affected_users
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.total_nft_count > 0
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL);
