-- 7E0A1Eのafffiliate_cycleとnft_masterを再確認

SELECT '=== affiliate_cycle（表示に使用） ===' as section;

SELECT
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== nft_master（実データ） ===' as section;

SELECT
    nft_type,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as available,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as bought_back,
    COUNT(*) as total
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type;

-- フロントエンドのクエリをシミュレート
SELECT '=== フロントエンドが取得するデータ ===' as section;

SELECT
    manual_nft_count,
    auto_nft_count,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';
