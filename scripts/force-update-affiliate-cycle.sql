-- affiliate_cycleを強制更新してキャッシュをクリア

UPDATE affiliate_cycle
SET
    manual_nft_count = 0,
    auto_nft_count = 2,
    total_nft_count = 2,
    last_updated = NOW()
WHERE user_id = '7E0A1E';

-- 確認
SELECT
    '=== 強制更新後 ===' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7E0A1E';
