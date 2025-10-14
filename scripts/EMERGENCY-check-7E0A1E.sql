-- ========================================
-- 7E0A1Eの600枚NFT問題を緊急調査
-- ========================================

-- 1. 7E0A1Eのユーザー情報
SELECT
    'ユーザー情報' as section,
    user_id,
    email,
    total_purchases,
    has_approved_nft,
    operation_start_date,
    created_at
FROM users
WHERE user_id = '7E0A1E';

-- 2. 7E0A1Eのaffiliate_cycle
SELECT
    'affiliate_cycle情報' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 3. 7E0A1Eのnft_master（全NFT）
SELECT
    'nft_master情報' as section,
    id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
ORDER BY nft_sequence;

-- 4. 7E0A1Eのpurchases（購入履歴）
SELECT
    'purchases情報' as section,
    id,
    nft_quantity,
    amount_usd,
    admin_approved,
    is_auto_purchase,
    admin_approved_at,
    created_at
FROM purchases
WHERE user_id = '7E0A1E'
ORDER BY created_at;

-- 5. 600枚は本当に購入されたのか？
SELECT
    '購入合計' as section,
    SUM(nft_quantity) as total_purchased_nft,
    SUM(amount_usd) as total_purchased_amount,
    COUNT(*) as purchase_count
FROM purchases
WHERE user_id = '7E0A1E'
  AND admin_approved = true;

-- 6. nft_masterに600枚分のレコードがあるか？
SELECT
    'nft_master合計' as section,
    COUNT(*) as total_nft_records,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_count,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_count,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_count
FROM nft_master
WHERE user_id = '7E0A1E';
