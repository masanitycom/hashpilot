-- ユーザー2BF53BのNFTデータを正しく修正（手動2枚、自動0枚）

-- 1. 現在のデータを確認
SELECT 
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE user_id = '2BF53B';

-- 2. ユーザー2BF53BのNFT数を手動2枚、自動0枚に修正
UPDATE affiliate_cycle
SET 
    manual_nft_count = 2,
    auto_nft_count = 0,
    total_nft_count = 2,
    last_updated = NOW()
WHERE user_id = '2BF53B';

-- 3. 更新後のデータを確認
SELECT 
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    last_updated
FROM affiliate_cycle
WHERE user_id = '2BF53B';

-- 4. メッセージ
SELECT 'ユーザー2BF53BのNFTデータを更新しました: 手動購入NFT=2枚、自動購入NFT=0枚' as message;