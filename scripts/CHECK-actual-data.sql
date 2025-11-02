-- 実際に保存されているデータを確認

SELECT '【daily_yield_log】' as table_name;
SELECT date, yield_rate, margin_rate, user_rate, created_at
FROM daily_yield_log
WHERE date = '2025-11-01'
ORDER BY created_at DESC;

SELECT '【nft_daily_profit サンプル5件】' as table_name;
SELECT user_id, date, daily_profit, yield_rate
FROM nft_daily_profit
WHERE date = '2025-11-01'
LIMIT 5;

SELECT '【user_referral_profit サンプル5件】' as table_name;
SELECT user_id, date, referral_level, profit_amount
FROM user_referral_profit
WHERE date = '2025-11-01'
LIMIT 5;

SELECT '【合計確認】' as info;
SELECT
    (SELECT SUM(daily_profit) FROM nft_daily_profit WHERE date = '2025-11-01') as total_nft_profit,
    (SELECT SUM(profit_amount) FROM user_referral_profit WHERE date = '2025-11-01') as total_referral_profit;
