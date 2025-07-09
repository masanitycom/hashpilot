-- user_daily_profitテーブルの構造を確認
SELECT 'user_daily_profit table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit' 
ORDER BY ordinal_position;

-- daily_yield_logテーブルの構造を確認
SELECT 'daily_yield_log table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
ORDER BY ordinal_position;

-- company_daily_profitテーブルの構造を確認
SELECT 'company_daily_profit table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'company_daily_profit' 
ORDER BY ordinal_position;

-- affiliate_rewardsテーブルの構造を確認
SELECT 'affiliate_rewards table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'affiliate_rewards' 
ORDER BY ordinal_position;
