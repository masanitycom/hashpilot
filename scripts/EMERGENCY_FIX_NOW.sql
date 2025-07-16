-- 🚨🚨🚨 緊急修正 - 即座に実行してください 🚨🚨🚨

-- 1. 7/15の全不正利益を削除
DELETE FROM user_daily_profit WHERE date = '2025-07-15';

-- 2. 全ユーザーの累積利益を再計算
UPDATE affiliate_cycle 
SET cum_usdt = (
    SELECT COALESCE(SUM(daily_profit), 0)
    FROM user_daily_profit 
    WHERE user_id = affiliate_cycle.user_id
),
available_usdt = (
    SELECT COALESCE(SUM(daily_profit), 0)
    FROM user_daily_profit 
    WHERE user_id = affiliate_cycle.user_id
),
updated_at = NOW();

-- 3. 承認なしユーザー794682の全利益削除
DELETE FROM user_daily_profit WHERE user_id = '794682';
UPDATE affiliate_cycle SET cum_usdt = 0, available_usdt = 0 WHERE user_id = '794682';

-- 4. 確認
SELECT '修正完了' as status, COUNT(*) as remaining_715_profits FROM user_daily_profit WHERE date = '2025-07-15';