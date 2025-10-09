-- A4C3C8 と 7A9637 の詳細調査

SELECT '=== A4C3C8 の調査 ===' as section;

-- ユーザー情報
SELECT
    user_id,
    email,
    username,
    total_purchases,
    has_approved_nft,
    created_at,
    operation_start_date
FROM users
WHERE user_id = 'A4C3C8';

-- 購入履歴
SELECT
    id,
    nft_quantity,
    amount_usd,
    payment_method,
    status,
    admin_approved,
    is_auto_purchase,
    created_at,
    approval_date
FROM purchases
WHERE user_id = 'A4C3C8'
ORDER BY created_at;

-- 購入回数と合計
SELECT
    COUNT(*) as purchase_count,
    SUM(CAST(amount_usd AS DECIMAL)) as total_amount,
    SUM(nft_quantity) as total_nft,
    COUNT(CASE WHEN is_auto_purchase = true THEN 1 END) as auto_purchase_count,
    COUNT(CASE WHEN is_auto_purchase = false THEN 1 END) as manual_purchase_count
FROM purchases
WHERE user_id = 'A4C3C8'
  AND admin_approved = true;

-- NFT master
SELECT
    nft_id,
    nft_type,
    purchase_id,
    created_at
FROM nft_master
WHERE user_id = 'A4C3C8'
ORDER BY created_at;

SELECT '=== 7A9637 の調査 ===' as section;

-- ユーザー情報
SELECT
    user_id,
    email,
    username,
    total_purchases,
    has_approved_nft,
    created_at,
    operation_start_date
FROM users
WHERE user_id = '7A9637';

-- affiliate_cycle 詳細
SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    cycle_number,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 購入履歴
SELECT
    id,
    nft_quantity,
    amount_usd,
    payment_method,
    status,
    admin_approved,
    is_auto_purchase,
    created_at,
    approval_date
FROM purchases
WHERE user_id = '7A9637'
ORDER BY created_at;

-- 自動購入の詳細
SELECT
    id,
    nft_quantity,
    amount_usd,
    created_at,
    approval_date
FROM purchases
WHERE user_id = '7A9637'
  AND is_auto_purchase = true
ORDER BY created_at;

-- NFT master（自動付与NFTの数）
SELECT
    COUNT(*) as total_nft_count,
    COUNT(CASE WHEN nft_type = 'auto' THEN 1 END) as auto_nft_count,
    COUNT(CASE WHEN nft_type = 'manual' THEN 1 END) as manual_nft_count
FROM nft_master
WHERE user_id = '7A9637';

-- 日次利益履歴（最近10日分）
SELECT
    date,
    daily_profit,
    base_amount,
    yield_rate,
    user_rate
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 累計利益
SELECT
    SUM(daily_profit) as total_profit,
    COUNT(*) as days_count,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit
WHERE user_id = '7A9637';
