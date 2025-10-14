-- ========================================
-- 7E0A1EのNFTを復元
-- ========================================
-- 目的: テストのため、買い取り済みの600枚のNFTを復元
-- 対象ユーザー: 7E0A1E
-- 復元内容:
--   - 600枚の手動NFT（buyback_dateをNULLに設定）
--   - affiliate_cycleのNFTカウントを更新

-- 1. 現在の状態を確認
SELECT
    '復元前: nft_master' as section,
    COUNT(*) as total_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as buyback_nft,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_total,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_total
FROM nft_master
WHERE user_id = '7E0A1E';

SELECT
    '復元前: affiliate_cycle' as section,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 2. 600枚の手動NFTを復元（buyback_dateをNULLに）
UPDATE nft_master
SET
    buyback_date = NULL,
    updated_at = NOW()
WHERE user_id = '7E0A1E'
  AND nft_type = 'manual'
  AND buyback_date IS NOT NULL;

-- 3. affiliate_cycleを更新
UPDATE affiliate_cycle
SET
    manual_nft_count = 600,
    total_nft_count = 600,  -- auto_nft_countは0のまま
    last_updated = NOW()
WHERE user_id = '7E0A1E';

-- 4. 復元後の状態を確認
SELECT
    '復元後: nft_master' as section,
    COUNT(*) as total_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as buyback_nft,
    COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_active,
    COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as auto_active
FROM nft_master
WHERE user_id = '7E0A1E';

SELECT
    '復元後: affiliate_cycle' as section,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 5. 復元されたNFTの詳細（最初の10件のみ）
SELECT
    '復元されたNFT（サンプル）' as section,
    id,
    nft_type,
    nft_sequence,
    nft_value,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
  AND nft_type = 'manual'
ORDER BY nft_sequence
LIMIT 10;

-- 完了メッセージ
SELECT '✅ 7E0A1Eの600枚のNFTを復元しました' as status;
