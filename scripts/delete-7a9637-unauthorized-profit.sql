-- 🚨 7A9637の不正利益削除
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

-- 3. 削除確認
SELECT 
    '=== 削除結果確認 ===' as check_type,
    user_id,
    COUNT(*) as remaining_profit_days,
    SUM(daily_profit) as total_profit,
    MAX(date) as last_profit_date
FROM user_daily_profit 
WHERE user_id = '7A9637'
GROUP BY user_id;

-- 4. affiliate_cycle確認
SELECT 
    '=== サイクル状況確認 ===' as check_type,
    user_id,
    cum_usdt,
    available_usdt,
    total_nft_count
FROM affiliate_cycle 
WHERE user_id = '7A9637';

-- 5. 7/15の利益が完全に削除されたか確認
SELECT 
    '=== 7/15利益削除確認 ===' as check_type,
    COUNT(*) as users_with_715_profit
FROM user_daily_profit 
WHERE date = '2025-07-15';