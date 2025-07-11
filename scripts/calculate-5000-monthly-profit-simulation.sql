-- 毎月5000ドル利益のユーザーのシミュレーション

-- 前提条件：
-- - 毎月5000ドルの利益
-- - 初期available_usdt = 0, cum_usdt = 0
-- - NFT自動購入: cum_usdt ≥ 2200 で 1NFT購入、cum_usdt -= 2200, available_usdt += 1100

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
        
        -- NFT自動購入回数計算
        FLOOR((cum_usdt_start + monthly_profit) / 2200) as auto_nft_purchases,
        
        -- NFT購入後のcum_usdt
        (cum_usdt_start + monthly_profit) - (FLOOR((cum_usdt_start + monthly_profit) / 2200) * 2200) as cum_usdt_end,
        
        -- NFT購入でavailable_usdtに追加される額
        FLOOR((cum_usdt_start + monthly_profit) / 2200) * 1100 as nft_to_available,
        
        -- 月末のavailable_usdt
        available_usdt_start + (FLOOR((cum_usdt_start + monthly_profit) / 2200) * 1100) as available_usdt_end,
        
        -- 累計NFT購入数
        nft_start + FLOOR((cum_usdt_start + monthly_profit) / 2200) as total_nft_purchased
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
        -- NFT購入数（2200ドルごと）
        FLOOR((month_num * 5000) / 2200) as total_nft_purchased,
        -- 累計available_usdt（NFT購入数 × 1100）
        FLOOR((month_num * 5000) / 2200) * 1100 as total_available_received,
        -- 残りのcum_usdt
        (month_num * 5000) - (FLOOR((month_num * 5000) / 2200) * 2200) as remaining_cum_usdt
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

SELECT '毎月5000ドル利益のシミュレーション完了' as message;