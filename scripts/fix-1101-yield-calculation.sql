-- 11/1の日利データを修正するスクリプト
-- 問題: 二重割り算により -0.02% が -0.012% として保存されている

-- 1. 現在の11/1のデータを確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    '現在の値' as note
FROM daily_yield_log
WHERE date = '2025-11-01';

-- 2. 正しい値を計算
-- yield_rate: -0.020% (パーセント表示)
-- 正しいuser_rate = -0.020 × (1 - 30/100) × 0.6 = -0.0084

-- 3. daily_yield_logテーブルを修正
UPDATE daily_yield_log
SET
    yield_rate = -0.020,
    user_rate = -0.020 * (1 - 30.0/100) * 0.6
WHERE date = '2025-11-01';

-- 4. user_daily_profitテーブルも修正が必要
-- 各ユーザーの利益を再計算
DO $$
DECLARE
    v_nft_record RECORD;
    v_user_rate NUMERIC := -0.020 * (1 - 30.0/100) * 0.6; -- -0.0084
    v_daily_profit NUMERIC;
BEGIN
    -- 11/1の全NFTの利益を再計算
    FOR v_nft_record IN
        SELECT 
            nm.id as nft_id,
            nm.user_id,
            nm.nft_value,
            udp.id as profit_id
        FROM nft_master nm
        INNER JOIN users u ON nm.user_id = u.user_id
        LEFT JOIN user_daily_profit udp ON udp.user_id = nm.user_id AND udp.date = '2025-11-01'
        WHERE nm.status = 'active'
        AND u.has_approved_nft = true
        AND (u.operation_start_date IS NULL OR u.operation_start_date <= '2025-11-01')
    LOOP
        -- 正しい利益額を計算
        v_daily_profit := v_nft_record.nft_value * v_user_rate / 100;
        
        -- user_daily_profitを更新
        UPDATE user_daily_profit
        SET daily_profit = v_daily_profit
        WHERE user_id = v_nft_record.user_id
        AND date = '2025-11-01';
        
        RAISE NOTICE '更新: user_id=%, nft_value=%, daily_profit=%', 
            v_nft_record.user_id, v_nft_record.nft_value, v_daily_profit;
    END LOOP;
END $$;

-- 5. affiliate_cycleテーブルも確認・修正が必要な場合
-- 紹介報酬の再計算（必要に応じて）
-- ※ 紹介報酬は累積額なので、差分を調整する必要がある

-- 6. 修正後のデータを確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    '修正後の値' as note
FROM daily_yield_log
WHERE date = '2025-11-01';

-- 7. ユーザー利益の合計を確認
SELECT 
    date,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-11-01'
GROUP BY date;
