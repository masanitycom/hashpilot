/* ユーザー2BF53BのNFT数を復元してテスト可能にする */

/* 1. 現在のpending申請をキャンセル状態に変更 */
UPDATE buyback_requests 
SET 
    status = 'cancelled',
    processed_at = NOW(),
    processed_by = 'system_auto',
    admin_notes = '新しい関数テストのため自動キャンセル'
WHERE user_id = '2BF53B' 
  AND status = 'pending';

/* 2. NFT保有数を1枚に復元 */
UPDATE affiliate_cycle 
SET 
    manual_nft_count = 1,
    auto_nft_count = 0,
    total_nft_count = 1,
    updated_at = NOW()
WHERE user_id = '2BF53B';

/* 3. 復元ログを記録 */
INSERT INTO system_logs (log_type, operation, user_id, message, details)
VALUES (
    'INFO',
    'nft_restore_for_testing',
    '2BF53B',
    'テスト用にNFT保有数を復元し、pending申請をキャンセル',
    jsonb_build_object(
        'restored_nft_count', 1,
        'cancelled_requests', 1,
        'reason', '新しいcreate_buyback_request関数のテスト',
        'timestamp', NOW()
    )
);

/* 4. 復元後の状況確認 */
SELECT 
    'Restored NFT Holdings' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    updated_at
FROM affiliate_cycle 
WHERE user_id = '2BF53B';

/* 5. キャンセルされた申請確認 */
SELECT 
    'Cancelled Requests' as section,
    id,
    user_id,
    status,
    admin_notes,
    processed_at
FROM buyback_requests 
WHERE user_id = '2BF53B' 
  AND status = 'cancelled'
ORDER BY processed_at DESC
LIMIT 3;