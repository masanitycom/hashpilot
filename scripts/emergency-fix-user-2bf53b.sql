/* ユーザー2BF53Bの緊急修正 - 申請済みNFTを即座に減少 */

/* 1. 現在の状況を記録 */
INSERT INTO system_logs (log_type, operation, user_id, message, details)
VALUES (
    'INFO',
    'emergency_nft_fix',
    '2BF53B',
    '緊急修正: 申請済みNFTの即座減少処理を実行',
    jsonb_build_object(
        'before_fix_nft_count', 1,
        'buyback_request_id', 'ee74f4a5-171d-4f6d-89ed-053487e7520c',
        'reason', '申請時のNFT減少処理が実行されていなかった'
    )
);

/* 2. ユーザー2BF53BのNFT保有数を正しく調整 */
/* 現在1枚保有 → 1枚申請済み → 0枚になるべき */
UPDATE affiliate_cycle 
SET 
    manual_nft_count = 0,
    auto_nft_count = 0,
    total_nft_count = 0,
    updated_at = NOW()
WHERE user_id = '2BF53B';

/* 3. 修正完了ログ */
INSERT INTO system_logs (log_type, operation, user_id, message, details)
VALUES (
    'SUCCESS',
    'emergency_nft_fix_completed',
    '2BF53B',
    'NFT保有数の緊急修正が完了しました',
    jsonb_build_object(
        'after_fix_nft_count', 0,
        'buyback_request_status', 'pending',
        'fix_timestamp', NOW()
    )
);

/* 4. 修正後の状況確認 */
SELECT 
    'After Fix - NFT Holdings' as section,
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

/* 5. 買い取り申請状況確認 */
SELECT 
    'After Fix - Buyback Request' as section,
    id,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_buyback_amount,
    status,
    request_date
FROM buyback_requests 
WHERE user_id = '2BF53B' 
  AND status = 'pending';