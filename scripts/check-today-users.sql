-- 今日登録したユーザーを確認

SELECT '=== 今日登録したユーザー ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.has_approved_nft,
    u.total_purchases,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.total_nft_count,
    u.created_at
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE DATE(u.created_at) = CURRENT_DATE
ORDER BY u.created_at DESC;

SELECT '=== 今日登録 & NFT承認済み ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.total_nft_count,
    p.admin_approved,
    p.created_at as purchase_date
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN purchases p ON u.user_id = p.user_id
WHERE DATE(u.created_at) = CURRENT_DATE
  AND ac.total_nft_count > 0
ORDER BY u.created_at DESC;

SELECT '=== 今日登録 & プロフィールアクセス問題がある可能性 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.total_nft_count,
    CASE
        WHEN ac.total_nft_count > 0 AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL)
        THEN '❌ 問題あり (NFT持ってるのにフラグfalse)'
        WHEN ac.total_nft_count > 0 AND u.has_approved_nft = true
        THEN '✅ OK'
        WHEN ac.total_nft_count = 0 OR ac.total_nft_count IS NULL
        THEN '⚠️  NFTなし'
        ELSE '?'
    END as status
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE DATE(u.created_at) = CURRENT_DATE
ORDER BY u.created_at DESC;
