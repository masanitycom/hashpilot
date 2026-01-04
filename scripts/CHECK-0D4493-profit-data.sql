-- 0D4493の利益データ確認
SELECT '=== nft_daily_profit ===' as section;
SELECT date, daily_profit
FROM nft_daily_profit
WHERE user_id = '0D4493'
ORDER BY date DESC
LIMIT 5;

SELECT '=== user_daily_profit ===' as section;
SELECT date, daily_profit, user_rate
FROM user_daily_profit
WHERE user_id = '0D4493'
ORDER BY date DESC
LIMIT 5;
