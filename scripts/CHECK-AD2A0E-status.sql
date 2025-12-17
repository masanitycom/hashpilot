-- AD2A0Eユーザーの状態確認
SELECT 
    user_id,
    email,
    is_active_investor,
    has_approved_nft,
    total_purchases,
    created_at
FROM users
WHERE user_id = 'AD2A0E';

-- このユーザーのNFT購入履歴
SELECT 
    id,
    user_id,
    amount_usd,
    admin_approved,
    created_at,
    admin_approved_at
FROM purchases
WHERE user_id = 'AD2A0E'
ORDER BY created_at DESC;

-- このユーザーのNFT保有状況
SELECT 
    id,
    user_id,
    nft_type,
    acquired_date,
    buyback_date
FROM nft_master
WHERE user_id = 'AD2A0E';
