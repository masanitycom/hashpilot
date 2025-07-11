-- 毎月5000ドル利益のユーザーのシミュレーション

-- 正しい前提条件：
-- - 毎月5000ドルの利益
-- - 初期available_usdt = 0, cum_usdt = 0  
-- - NFT自動購入: cum_usdt ≥ 1100 で 1NFT購入、cum_usdt -= 1100, available_usdt += 1100
-- - つまり1100ドル溜まるたびに、NFTを1枚もらい、同時に1100ドルも受け取れる

WITH monthly_simulation AS (
    SELECT 
        month_num,
        monthly_profit,
        -- 前月からの累計
        LAG(cum_usdt_end, 1, 0) OVER (ORDER BY month_num) as cum_usdt_start,
        LAG(available_usdt_end, 1, 0) OVER (ORDER BY month_num) as available_usdt_start,
        LAG(total_nft_purchased, 1, 0) OVER (ORDER BY month_num) as nft_start
    FROM (
        SELECT 
            generate_series(1, 5) as month_num,
            5000 as monthly_profit
    ) base
),
cycle_calculations AS (
    SELECT 
        month_num,
        monthly_profit,
        cum_usdt_start,
        available_usdt_start,
        nft_start,
        
        -- 今月の利益追加後
        cum_usdt_start + monthly_profit as cum_usdt_after_profit,
        
        -- NFT自動購入回数計算（1100ドルごと）
        FLOOR((cum_usdt_start + monthly_profit) / 1100) as auto_nft_purchases,
        
        -- NFT購入後のcum_usdt（残り）
        (cum_usdt_start + monthly_profit) - (FLOOR((cum_usdt_start + monthly_profit) / 1100) * 1100) as cum_usdt_end,
        
        -- NFT購入でavailable_usdtに追加される額（NFT枚数 × 1100）
        FLOOR((cum_usdt_start + monthly_profit) / 1100) * 1100 as nft_to_available,
        
        -- 月末のavailable_usdt
        available_usdt_start + (FLOOR((cum_usdt_start + monthly_profit) / 1100) * 1100) as available_usdt_end,
        
        -- 累計NFT購入数
        nft_start + FLOOR((cum_usdt_start + monthly_profit) / 1100) as total_nft_purchased
    FROM monthly_simulation
)
SELECT 
    month_num as "月",
    monthly_profit as "今月利益($)",
    cum_usdt_start as "月初cum_usdt($)",
    available_usdt_start as "月初available($)",
    nft_start as "月初NFT数",
    cum_usdt_after_profit as "利益追加後cum($)",
    auto_nft_purchases as "今月NFT自動購入数",
    nft_to_available as "NFT→available転換($)",
    cum_usdt_end as "月末cum_usdt($)",
    available_usdt_end as "月末available($)",
    total_nft_purchased as "累計NFT購入数",
    
    -- 実際にユーザーが受け取れる額（available_usdt）
    CASE 
        WHEN month_num = 1 THEN available_usdt_end
        ELSE available_usdt_end - LAG(available_usdt_end, 1, 0) OVER (ORDER BY month_num)
    END as "今月受取可能額($)",
    
    -- フェーズ判定
    CASE 
        WHEN cum_usdt_end < 1100 THEN 'USDTフェーズ'
        WHEN cum_usdt_end < 2200 THEN 'HOLDフェーズ'
        ELSE 'NFT購入予定'
    END as "月末フェーズ"
FROM cycle_calculations
ORDER BY month_num;

-- 5年間のシミュレーション概要
WITH long_term_simulation AS (
    SELECT 
        month_num,
        -- 累計利益
        month_num * 5000 as total_profit_received,
        -- NFT購入数（1100ドルごと）
        FLOOR((month_num * 5000) / 1100) as total_nft_purchased,
        -- 累計available_usdt（NFT購入数 × 1100）
        FLOOR((month_num * 5000) / 1100) * 1100 as total_available_received,
        -- 残りのcum_usdt
        (month_num * 5000) - (FLOOR((month_num * 5000) / 1100) * 1100) as remaining_cum_usdt
    FROM generate_series(1, 60) as month_num  -- 5年 = 60ヶ月
    WHERE month_num IN (12, 24, 36, 48, 60)  -- 1年、2年、3年、4年、5年
)
SELECT 
    month_num / 12.0 as "経過年数",
    total_profit_received as "累計利益($)",
    total_nft_purchased as "累計NFT購入数",
    total_available_received as "累計USDT受取($)",
    remaining_cum_usdt as "残りcum_usdt($)",
    ROUND((total_available_received::NUMERIC / total_profit_received) * 100, 2) as "利益に対する受取率(%)"
FROM long_term_simulation
ORDER BY month_num;

-- 手動計算での確認
SELECT '=== 手動計算確認 ===' as section;

-- 1ヶ月目: 5000ドル
SELECT 
    '1ヶ月目' as month,
    5000 as profit,
    FLOOR(5000 / 1100) as nft_count,
    FLOOR(5000 / 1100) * 1100 as usdt_received,
    5000 - (FLOOR(5000 / 1100) * 1100) as remaining_cum_usdt,
    '5000 → 4NFT + 4400USDT + 600保留' as explanation
UNION ALL
-- 2ヶ月目: 600 + 5000 = 5600ドル  
SELECT 
    '2ヶ月目' as month,
    5600 as profit,
    FLOOR(5600 / 1100) as nft_count,
    FLOOR(5600 / 1100) * 1100 as usdt_received,
    5600 - (FLOOR(5600 / 1100) * 1100) as remaining_cum_usdt,
    '600+5000 → 5NFT + 5500USDT + 100保留' as explanation
UNION ALL
-- 3ヶ月目: 100 + 5000 = 5100ドル
SELECT 
    '3ヶ月目' as month,
    5100 as profit,
    FLOOR(5100 / 1100) as nft_count,
    FLOOR(5100 / 1100) * 1100 as usdt_received,
    5100 - (FLOOR(5100 / 1100) * 1100) as remaining_cum_usdt,
    '100+5000 → 4NFT + 4400USDT + 700保留' as explanation
UNION ALL
-- 4ヶ月目: 700 + 5000 = 5700ドル
SELECT 
    '4ヶ月目' as month,
    5700 as profit,
    FLOOR(5700 / 1100) as nft_count,
    FLOOR(5700 / 1100) * 1100 as usdt_received,
    5700 - (FLOOR(5700 / 1100) * 1100) as remaining_cum_usdt,
    '700+5000 → 5NFT + 5500USDT + 200保留' as explanation
UNION ALL
-- 5ヶ月目: 200 + 5000 = 5200ドル
SELECT 
    '5ヶ月目' as month,
    5200 as profit,
    FLOOR(5200 / 1100) as nft_count,
    FLOOR(5200 / 1100) * 1100 as usdt_received,
    5200 - (FLOOR(5200 / 1100) * 1100) as remaining_cum_usdt,
    '200+5000 → 4NFT + 4400USDT + 800保留' as explanation;

SELECT '毎月5000ドル利益のシミュレーション完了' as message;