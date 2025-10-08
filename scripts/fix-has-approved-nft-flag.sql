-- NFTを持っているのに has_approved_nft=false のユーザーを修正

SELECT '=== 修正前の状態 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.total_nft_count
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.total_nft_count > 0
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL);

-- has_approved_nft フラグを修正
UPDATE users
SET has_approved_nft = true
WHERE user_id IN (
    SELECT u.user_id
    FROM users u
    INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.total_nft_count > 0
      AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL)
);

SELECT '=== 修正後の確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.total_nft_count
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE user_id IN ('368E3F', '307FD5', '328E04', '2EAA6E', 'E28F37');
