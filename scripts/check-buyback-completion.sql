-- 買い取り完了後の状態確認

-- 買い取り申請の状態
SELECT
    '=== 買い取り申請の状態 ===' as section,
    id,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    status,
    processed_by,
    processed_at
FROM buyback_requests
WHERE user_id = '7E0A1E'
ORDER BY created_at DESC
LIMIT 1;

-- NFTマスターの状態
SELECT
    '=== NFTマスターの状態 ===' as section,
    nft_type,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as available,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as bought_back
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type;

-- affiliate_cycleの状態
SELECT
    '=== affiliate_cycleの状態 ===' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 買い取り済みNFTの詳細
SELECT
    '=== 買い取り済みNFT ===' as section,
    nft_sequence,
    nft_type,
    buyback_date
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NOT NULL
ORDER BY nft_sequence
LIMIT 10;
