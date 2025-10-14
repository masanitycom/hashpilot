-- 7E0A1EのNFTマスターを詳細確認

-- 全てのNFT（buyback含む）
SELECT
    'NFTマスター（全件）' as section,
    nft_type,
    nft_sequence,
    nft_value,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
ORDER BY nft_sequence;

-- 件数サマリー
SELECT
    'NFT件数サマリー' as section,
    COUNT(*) as total_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as buyback_nft,
    COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as active_manual,
    COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as active_auto
FROM nft_master
WHERE user_id = '7E0A1E';
