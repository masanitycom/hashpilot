-- 🚨 7A9637の不正利益を削除
-- 2025年1月16日 緊急修正

-- 1. 7A9637の7/15利益を削除
DELETE FROM user_daily_profit 
WHERE user_id = '7A9637' 
AND date = '2025-07-15';

-- 2. 7A9637の累積利益を再計算
UPDATE affiliate_cycle 
SET cum_usdt = (
    SELECT COALESCE(SUM(daily_profit), 0)
    FROM user_daily_profit 
    WHERE user_id = '7A9637'
),
available_usdt = (
    SELECT COALESCE(SUM(daily_profit), 0)
    FROM user_daily_profit 
    WHERE user_id = '7A9637'
),
updated_at = NOW()
WHERE user_id = '7A9637';

-- 3. 確認
SELECT 
    'fix_result' as check_type,
    user_id,
    COUNT(*) as profit_days,
    SUM(daily_profit) as total_profit,
    MAX(date) as last_date
FROM user_daily_profit 
WHERE user_id = '7A9637'
GROUP BY user_id;

SELECT 
    'cycle_result' as check_type,
    user_id,
    cum_usdt,
    available_usdt
FROM affiliate_cycle 
WHERE user_id = '7A9637';