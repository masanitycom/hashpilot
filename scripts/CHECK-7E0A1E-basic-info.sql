-- 7E0A1Eの基本情報確認
SELECT
    user_id,
    has_approved_nft,
    operation_start_date,
    total_purchases,
    created_at
FROM users
WHERE user_id = '7E0A1E';

-- 7E0A1EのNFT件数
SELECT
    COUNT(*) as total_nft,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_nft,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_nft
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL;
