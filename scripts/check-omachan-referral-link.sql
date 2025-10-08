-- omachan080522@gmail.com ユーザーの紹介リンク表示問題を調査

-- ユーザー情報確認
SELECT
    '=== ユーザー情報 ===' as section,
    user_id,
    email,
    coinw_uid,
    nft_receive_address,
    total_purchases,
    created_at
FROM users
WHERE email = 'omachan080522@gmail.com';

-- 購入履歴確認
SELECT
    '=== 購入履歴 ===' as section,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    admin_approved,
    admin_approved_at,
    created_at
FROM purchases
WHERE user_id = (SELECT user_id FROM users WHERE email = 'omachan080522@gmail.com')
ORDER BY created_at DESC;

-- affiliate_cycle確認
SELECT
    '=== affiliate_cycle ===' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = (SELECT user_id FROM users WHERE email = 'omachan080522@gmail.com');

-- nft_master確認
SELECT
    '=== nft_master ===' as section,
    user_id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date
FROM nft_master
WHERE user_id = (SELECT user_id FROM users WHERE email = 'omachan080522@gmail.com')
ORDER BY nft_sequence;
