-- 正しいサイクル処理のシミュレーション（交互パターン）

-- 重要な仕様：
-- 1100ドルごとに交互に「USDT受取」→「NFT購入」→「USDT受取」→「NFT購入」...
-- next_actionが「usdt」なら次はUSDT受取、「nft」なら次はNFT購入

CREATE OR REPLACE FUNCTION simulate_cycle_processing(
    monthly_profit NUMERIC,
    months INTEGER,
    initial_remaining NUMERIC DEFAULT 0,
    initial_next_action TEXT DEFAULT 'usdt'
) RETURNS TABLE (
    month_num INTEGER,
    starting_amount NUMERIC,
    total_amount NUMERIC,
    usdt_received NUMERIC,
    nft_purchased INTEGER,
    remaining_amount NUMERIC,
    next_action TEXT,
    explanation TEXT
) AS $$
DECLARE
    current_remaining NUMERIC := initial_remaining;
    current_next_action TEXT := initial_next_action;
    current_month INTEGER;
    month_total NUMERIC;
    month_usdt NUMERIC;
    month_nft INTEGER;
    temp_amount NUMERIC;
    cycle_count INTEGER;
BEGIN
    FOR current_month IN 1..months LOOP
        -- 月初の状態
        month_total := current_remaining + monthly_profit;
        month_usdt := 0;
        month_nft := 0;
        temp_amount := month_total;
        
        -- 1100ドルごとのサイクル処理
        WHILE temp_amount >= 1100 LOOP
            IF current_next_action = 'usdt' THEN
                -- USDT受取
                month_usdt := month_usdt + 1100;
                current_next_action := 'nft';
            ELSE
                -- NFT購入
                month_nft := month_nft + 1;
                current_next_action := 'usdt';
            END IF;
            temp_amount := temp_amount - 1100;
        END LOOP;
        
        -- 1100未満の残り
        current_remaining := temp_amount;
        
        -- 結果を返す
        month_num := current_month;
        starting_amount := current_remaining + monthly_profit - temp_amount;
        total_amount := month_total;
        usdt_received := month_usdt;
        nft_purchased := month_nft;
        remaining_amount := current_remaining;
        next_action := current_next_action;
        explanation := format('%s月目: %sドル → %sUSDT + %sNFT + %s保留 (次:%s)',
            current_month, month_total, month_usdt, month_nft, current_remaining, current_next_action);
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 毎月5000ドル利益のシミュレーション実行
SELECT '=== 正しいサイクル処理シミュレーション ===' as section;

SELECT * FROM simulate_cycle_processing(5000, 5, 0, 'usdt');

-- 手動検証
SELECT '=== 手動検証 ===' as section;

WITH manual_check AS (
    SELECT 1 as month, 5000 as amount, 'usdt' as start_action
    UNION ALL SELECT 2, 5500, 'nft'  -- 前月残500 + 5000
    UNION ALL SELECT 3, 5100, 'nft'  -- 前月残100 + 5000  
    UNION ALL SELECT 4, 5700, 'usdt' -- 前月残700 + 5000
    UNION ALL SELECT 5, 5200, 'usdt' -- 前月残200 + 5000
)
SELECT 
    month,
    amount,
    start_action,
    FLOOR(amount / 1100) as cycles,
    CASE 
        WHEN start_action = 'usdt' THEN
            CASE 
                WHEN FLOOR(amount / 1100) % 2 = 1 THEN CEIL(FLOOR(amount / 1100) / 2.0) * 1100
                ELSE FLOOR(FLOOR(amount / 1100) / 2.0) * 1100
            END
        ELSE -- start_action = 'nft'
            CASE 
                WHEN FLOOR(amount / 1100) % 2 = 1 THEN FLOOR(FLOOR(amount / 1100) / 2.0) * 1100
                ELSE CEIL(FLOOR(amount / 1100) / 2.0) * 1100
            END
    END as expected_usdt,
    CASE 
        WHEN start_action = 'usdt' THEN FLOOR(FLOOR(amount / 1100) / 2.0)
        ELSE CEIL(FLOOR(amount / 1100) / 2.0)
    END as expected_nft,
    amount - (FLOOR(amount / 1100) * 1100) as expected_remaining
FROM manual_check;

-- あなたの例との比較
SELECT '=== 期待される結果との比較 ===' as section;
SELECT '1ヶ月目: 2800USDT + NFT2枚 (実際の期待値)' as expected
UNION ALL SELECT '2ヶ月目: 2700USDT + NFT2枚 + 保留100USDT'
UNION ALL SELECT '3ヶ月目: 2200USDT + NFT2枚 + 保留700USDT'
UNION ALL SELECT '4ヶ月目: 2400USDT + NFT3枚'  
UNION ALL SELECT '5ヶ月目: 2800USDT + NFT2枚';

-- 関数削除
DROP FUNCTION IF EXISTS simulate_cycle_processing;