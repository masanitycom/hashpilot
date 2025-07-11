-- 完全に正確なサイクルシミュレーション

-- 重要な仕様の確認：
-- 1. 1100ドルごとに「USDT受取」と「NFT購入」を交互に実行
-- 2. 1100ドル未満の場合：
--    - 次がUSDTの番なら、その金額をUSDT受取
--    - 次がNFTの番なら、保留して翌月に持ち越し

SELECT '=== 毎月5000ドル利益の正確な計算 ===' as section;

WITH simulation AS (
    SELECT 
        month_num,
        carry_over,
        total_amount,
        next_action_start,
        -- 処理結果
        usdt_received,
        nft_purchased,
        remaining,
        next_action_end
    FROM (
        -- 1ヶ月目: 5000ドル、USDTスタート
        SELECT 
            1 as month_num,
            0 as carry_over,
            5000 as total_amount,
            'usdt' as next_action_start,
            2800 as usdt_received,  -- 1100 + 1100 + 600
            2 as nft_purchased,
            0 as remaining,
            'usdt' as next_action_end  -- 600受取後もUSDTの番
            
        UNION ALL
        
        -- 2ヶ月目: 0+5000=5000ドル、USDTスタート
        SELECT 
            2 as month_num,
            0 as carry_over,
            5000 as total_amount,
            'usdt' as next_action_start,
            2700 as usdt_received,  -- 500 + 1100 + 1100
            2 as nft_purchased,
            100 as remaining,      -- NFTの番で100残り
            'nft' as next_action_end
            
        UNION ALL
        
        -- 3ヶ月目: 100+5000=5100ドル、NFTスタート
        SELECT 
            3 as month_num,
            100 as carry_over,
            5100 as total_amount,
            'nft' as next_action_start,
            2200 as usdt_received,  -- 1100 + 1100
            2 as nft_purchased,
            700 as remaining,       -- USDTの番で700残り（受取可能）
            'usdt' as next_action_end
            
        UNION ALL
        
        -- 4ヶ月目: 700+5000=5700ドル、USDTスタート
        SELECT 
            4 as month_num,
            700 as carry_over,
            5700 as total_amount,
            'usdt' as next_action_start,
            2400 as usdt_received,  -- 700 + 1100 + 600
            3 as nft_purchased,
            0 as remaining,
            'nft' as next_action_end
            
        UNION ALL
        
        -- 5ヶ月目: 0+5000=5000ドル、NFTスタート  
        SELECT 
            5 as month_num,
            0 as carry_over,
            5000 as total_amount,
            'nft' as next_action_start,
            2800 as usdt_received,  -- 1100 + 1100 + 600
            2 as nft_purchased,
            0 as remaining,
            'usdt' as next_action_end
    ) t
)
SELECT 
    month_num as "月",
    carry_over as "前月繰越($)",
    total_amount as "処理額($)",
    next_action_start as "開始時",
    usdt_received as "USDT受取($)",
    nft_purchased as "NFT購入(枚)",
    remaining as "翌月繰越($)",
    next_action_end as "終了時",
    -- 詳細説明
    CASE month_num
        WHEN 1 THEN 'USDT(1100)→NFT→USDT(1100)→NFT→USDT(600)'
        WHEN 2 THEN 'USDT(500)→NFT→USDT(1100)→NFT→USDT(1100)→残100'
        WHEN 3 THEN 'NFT(100+1000)→USDT(1100)→NFT→USDT(1100)→残700'
        WHEN 4 THEN 'USDT(700)→NFT→USDT(1100)→NFT→USDT(600)→NFT'
        WHEN 5 THEN 'NFT→USDT(1100)→NFT→USDT(1100)→残600→USDT(600)'
    END as "処理詳細"
FROM simulation
ORDER BY month_num;

-- 累計確認
SELECT '=== 5ヶ月間の累計 ===' as section;
SELECT 
    SUM(usdt_received) as "累計USDT受取($)",
    SUM(nft_purchased) as "累計NFT購入(枚)",
    5 * 5000 as "累計利益($)",
    ROUND((SUM(usdt_received)::NUMERIC / (5 * 5000)) * 100, 2) as "受取率(%)"
FROM simulation;

-- サイクル処理の重要ポイント
SELECT '=== サイクル処理の重要ポイント ===' as section;
SELECT 
    '1. 1100ドル未満でUSDTの番' as point,
    'その金額をUSDT受取（例: 600ドル）' as action
UNION ALL
SELECT 
    '2. 1100ドル未満でNFTの番' as point,
    '保留して翌月に持ち越し（例: 100ドル）' as action
UNION ALL
SELECT 
    '3. 交互サイクル' as point,
    'USDT→NFT→USDT→NFT...の順番を厳守' as action;