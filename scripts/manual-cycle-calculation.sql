-- 手動での正確なサイクル計算

SELECT '=== 毎月5000ドル利益の正確な計算 ===' as section;

-- 1ヶ月目: 5000ドル、開始は「USDT」の番
SELECT 
    '1ヶ月目' as month,
    '5000ドル開始、USDTの番から' as starting,
    '1. 1100 → USDT受取(1100)' as step1,
    '2. 1100 → NFT購入(1枚)' as step2,
    '3. 1100 → USDT受取(1100)' as step3,
    '4. 1100 → NFT購入(1枚)' as step4,
    '5. 600 → USDT受取(600)' as step5,
    '合計: 2800USDT + NFT2枚' as result,
    '次はNFTの番' as next_turn;

-- 2ヶ月目: 500残り + 5000 = 5500ドル、開始は「NFT」の番
SELECT 
    '2ヶ月目' as month,
    '500残り + 5000 = 5500ドル、NFTの番から' as starting,
    '1. 500 → USDT受取(500)' as step1,
    '2. 1100 → NFT購入(1枚)' as step2,
    '3. 1100 → USDT受取(1100)' as step3,
    '4. 1100 → NFT購入(1枚)' as step4,
    '5. 1100 → USDT受取(1100)' as step5,
    '100残り' as step6,
    '合計: 2700USDT + NFT2枚 + 100保留' as result,
    '次はNFTの番' as next_turn;

-- 3ヶ月目: 100残り + 5000 = 5100ドル、開始は「NFT」の番
SELECT 
    '3ヶ月目' as month,
    '100残り + 5000 = 5100ドル、NFTの番から' as starting,
    '1. 1100 → NFT購入(1枚)' as step1,
    '2. 1100 → USDT受取(1100)' as step2,
    '3. 1100 → NFT購入(1枚)' as step3,
    '4. 1100 → USDT受取(1100)' as step4,
    '700残り' as step5,
    '合計: 2200USDT + NFT2枚 + 700保留' as result,
    '次はUSDTの番' as next_turn;

-- 4ヶ月目: 700残り + 5000 = 5700ドル、開始は「USDT」の番
SELECT 
    '4ヶ月目' as month,
    '700残り + 5000 = 5700ドル、USDTの番から' as starting,
    '1. 1100 → USDT受取(1100)' as step1,
    '2. 1100 → NFT購入(1枚)' as step2,
    '3. 1100 → USDT受取(1100)' as step3,
    '4. 1100 → NFT購入(1枚)' as step4,
    '5. 1100 → USDT受取(1100)' as step5,
    '6. 200 → なし(200保留)' as step6,
    '合計: 3300USDT + NFT2枚 + 200保留' as result,
    '次はNFTの番' as next_turn;

-- あれ、4ヶ月目が合わないですね...
-- あなたの例では「2400USDT + NFT3枚」

-- 5ヶ月目: 200残り + 5000 = 5200ドル、開始は「NFT」の番
SELECT 
    '5ヶ月目' as month,
    '200残り + 5000 = 5200ドル、NFTの番から' as starting,
    '1. 1100 → NFT購入(1枚)' as step1,
    '2. 1100 → USDT受取(1100)' as step2,
    '3. 1100 → NFT購入(1枚)' as step3,
    '4. 1100 → USDT受取(1100)' as step4,
    '800残り' as step5,
    '合計: 2200USDT + NFT2枚 + 800保留' as result,
    '次はUSDTの番' as next_turn;

-- あなたの例では「2800USDT + NFT2枚」なので、まだ理解が間違っているようです