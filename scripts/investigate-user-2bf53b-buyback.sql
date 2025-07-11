/* ユーザー2BF53Bの買い取り申請問題を調査 */

/* 1. ユーザー2BF53Bの基本情報を確認 */
SELECT 
    'User Info' as section,
    user_id,
    email,
    full_name,
    total_purchases,
    is_active,
    created_at
FROM users 
WHERE user_id = '2BF53B';

/* 2. affiliate_cycleでのNFT保有状況を確認 */
SELECT 
    'NFT Holdings' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    updated_at
FROM affiliate_cycle 
WHERE user_id = '2BF53B';

/* 3. 買い取り申請履歴を確認 */
SELECT 
    'Buyback Requests' as section,
    id,
    user_id,
    request_date,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    total_buyback_amount,
    wallet_address,
    wallet_type,
    status,
    processed_at,
    processed_by
FROM buyback_requests 
WHERE user_id = '2BF53B'
ORDER BY request_date DESC;

/* 4. purchasesテーブルでの購入履歴を確認 */
SELECT 
    'Purchase History' as section,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    is_auto_purchase,
    created_at
FROM purchases 
WHERE user_id = '2BF53B'
ORDER BY created_at DESC;

/* 5. 日利履歴を確認 */
SELECT 
    'Daily Profit' as section,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase
FROM user_daily_profit 
WHERE user_id = '2BF53B'
ORDER BY date DESC
LIMIT 10;

/* 6. システムログを確認 */
SELECT 
    'System Logs' as section,
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs 
WHERE user_id = '2BF53B'
   OR (details->>'user_id' = '2BF53B')
   OR message LIKE '%2BF53B%'
ORDER BY created_at DESC
LIMIT 20;

/* 7. 計算の整合性をチェック */
SELECT 
    'Calculation Check' as section,
    ac.user_id,
    ac.total_nft_count as current_nft,
    COALESCE(SUM(p.nft_quantity), 0) as total_purchased,
    COALESCE(SUM(CASE WHEN br.status != 'cancelled' THEN br.total_nft_count ELSE 0 END), 0) as total_buyback_requested,
    (COALESCE(SUM(p.nft_quantity), 0) - COALESCE(SUM(CASE WHEN br.status != 'cancelled' THEN br.total_nft_count ELSE 0 END), 0)) as expected_nft
FROM affiliate_cycle ac
LEFT JOIN purchases p ON p.user_id = ac.user_id AND p.admin_approved = true
LEFT JOIN buyback_requests br ON br.user_id = ac.user_id
WHERE ac.user_id = '2BF53B'
GROUP BY ac.user_id, ac.total_nft_count;

/* 8. 最新の買い取り申請の詳細（もしあれば） */
SELECT 
    'Latest Buyback Detail' as section,
    br.*,
    'Expected remaining NFT:' as note,
    (ac.total_nft_count + br.total_nft_count) as nft_before_request
FROM buyback_requests br
JOIN affiliate_cycle ac ON ac.user_id = br.user_id
WHERE br.user_id = '2BF53B'
ORDER BY br.request_date DESC
LIMIT 1;