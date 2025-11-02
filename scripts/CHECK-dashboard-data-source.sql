-- ダッシュボードが表示しているデータソースを確認

-- 特定ユーザー（328E04）のデータを詳しく見る
SELECT '【328E04の詳細】' as info;

SELECT 'affiliate_cycle' as table_name, cum_usdt, available_usdt
FROM affiliate_cycle
WHERE user_id = '328E04';

SELECT 'nft_daily_profit（11/1）' as table_name, SUM(daily_profit) as total_personal
FROM nft_daily_profit
WHERE user_id = '328E04' AND date = '2025-11-01';

SELECT 'user_referral_profit（11/1）' as table_name, SUM(profit_amount) as total_referral
FROM user_referral_profit
WHERE user_id = '328E04' AND date = '2025-11-01';

-- 全期間の合計を確認
SELECT '【328E04 全期間】' as info;
SELECT
    (SELECT SUM(daily_profit) FROM nft_daily_profit WHERE user_id = '328E04') as total_personal_all,
    (SELECT SUM(profit_amount) FROM user_referral_profit WHERE user_id = '328E04') as total_referral_all,
    (SELECT available_usdt FROM affiliate_cycle WHERE user_id = '328E04') as available_usdt;
