-- 7E0A1Eの600枚の手動NFTを元に戻す

SELECT '=== 現在の状態 ===' as section;

SELECT
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT
    nft_type,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as available,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as bought_back
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type;

-- 買い取り済みの手動NFTを元に戻す（buyback_dateをNULLに）
UPDATE nft_master
SET buyback_date = NULL,
    updated_at = NOW()
WHERE user_id = '7E0A1E'
  AND nft_type = 'manual'
  AND buyback_date IS NOT NULL;

-- affiliate_cycleのカウントを更新
UPDATE affiliate_cycle
SET
    manual_nft_count = manual_nft_count + 600,
    total_nft_count = total_nft_count + 600,
    last_updated = NOW()
WHERE user_id = '7E0A1E';

SELECT '=== 復元後の状態 ===' as section;

SELECT
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT
    nft_type,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as available,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as bought_back
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type;

SELECT '=== 最新の買い取り申請を確認 ===' as section;

SELECT
    id,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_buyback_amount,
    status,
    processed_at
FROM buyback_requests
WHERE user_id = '7E0A1E'
ORDER BY created_at DESC
LIMIT 1;

-- 最新の買い取り申請のステータスを'cancelled'に変更（削除はしない）
UPDATE buyback_requests
SET status = 'cancelled',
    admin_notes = 'テスト後に復元'
WHERE user_id = '7E0A1E'
  AND id = (
    SELECT id FROM buyback_requests
    WHERE user_id = '7E0A1E'
    ORDER BY created_at DESC
    LIMIT 1
  );

SELECT '=== 完了 ===' as section;
SELECT '600枚の手動NFTを復元しました' as message;
