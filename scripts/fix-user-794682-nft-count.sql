-- User 794682のNFTカウント不整合を修正
-- 作成日: 2025年10月7日
-- 問題: affiliate_cycleには1 NFTとカウントされているが、実際のNFTレコードと購入記録が存在しない

-- 現状確認
SELECT
    '=== User 794682 Current Status ===' as check_name;

SELECT
    user_id,
    email,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '794682';

-- nft_masterの確認（実際のNFTレコード）
SELECT
    COUNT(*) as actual_nft_count,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as actual_manual,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as actual_auto
FROM nft_master
WHERE user_id = '794682' AND buyback_date IS NULL;

-- purchasesの確認
SELECT
    COUNT(*) as purchase_count,
    COALESCE(SUM(nft_quantity), 0) as total_purchased
FROM purchases
WHERE user_id = '794682' AND admin_approved = true;

-- 修正: NFTカウントを実際の数に合わせる（0にリセット）
UPDATE affiliate_cycle
SET
    total_nft_count = 0,
    manual_nft_count = 0,
    auto_nft_count = 0,
    last_updated = NOW()
WHERE user_id = '794682';

-- 修正後の確認
SELECT
    '=== After Fix ===' as check_name;

SELECT
    user_id,
    email,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '794682';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'User 794682 NFT count fixed';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Changes:';
    RAISE NOTICE '  - Reset total_nft_count from 1 to 0';
    RAISE NOTICE '  - Reset manual_nft_count from 1 to 0';
    RAISE NOTICE '  - No actual NFT records exist in nft_master';
    RAISE NOTICE '  - No purchase records exist in purchases';
    RAISE NOTICE '===========================================';
END $$;
