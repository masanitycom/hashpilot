-- ユーザー7E0A1Eの全データを確認

SELECT '=== Users テーブル ===' as section;
SELECT
    user_id,
    email,
    total_purchases,
    has_approved_nft,
    nft_receive_address
FROM users
WHERE user_id = '7E0A1E';

SELECT '=== affiliate_cycle テーブル ===' as section;
SELECT
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== nft_master 集計 ===' as section;
SELECT
    nft_type,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as available,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as bought_back
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type;

SELECT '=== 最新の買い取り申請 ===' as section;
SELECT
    id,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_buyback_amount,
    status,
    request_date,
    processed_at
FROM buyback_requests
WHERE user_id = '7E0A1E'
ORDER BY request_date DESC
LIMIT 1;

SELECT '=== Purchases テーブル ===' as section;
SELECT
    id,
    user_id,
    nft_quantity,
    total_amount,
    status,
    created_at,
    approved_at
FROM purchases
WHERE user_id = '7E0A1E'
ORDER BY created_at;
