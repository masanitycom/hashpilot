-- 7E0A1Eを探す
SELECT 'users テーブル' as section, * FROM users WHERE user_id = '7E0A1E';
SELECT 'users テーブル（LIKE検索）' as section, * FROM users WHERE user_id LIKE '%7E0A1E%';
SELECT 'users テーブル（全件数）' as section, COUNT(*) as total_users FROM users;

-- affiliate_cycleには存在するか
SELECT 'affiliate_cycle' as section, * FROM affiliate_cycle WHERE user_id = '7E0A1E';

-- nft_masterには存在するか
SELECT 'nft_master' as section, user_id, COUNT(*) as nft_count FROM nft_master WHERE user_id = '7E0A1E' GROUP BY user_id;

-- purchasesには存在するか
SELECT 'purchases' as section, user_id, COUNT(*) as purchase_count FROM purchases WHERE user_id = '7E0A1E' GROUP BY user_id;

-- user_daily_profitには存在するか
SELECT 'user_daily_profit' as section, user_id, COUNT(*) as profit_count FROM user_daily_profit WHERE user_id = '7E0A1E' GROUP BY user_id;
