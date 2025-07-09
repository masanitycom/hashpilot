-- Check the structure of monthly rewards related tables
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('user_monthly_rewards', 'affiliate_reward', 'admin_monthly_rewards_view')
ORDER BY table_name, ordinal_position;

-- Check if user_daily_profit table exists and its structure
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit'
ORDER BY ordinal_position;

-- Check existing data in user_monthly_rewards
SELECT COUNT(*) as total_records FROM user_monthly_rewards;

-- Check existing data in affiliate_reward
SELECT COUNT(*) as total_records FROM affiliate_reward;
