-- 強制的に全テーブルをクリア
SET session_replication_role = replica;

-- RLSを無効化
ALTER TABLE admins DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_cycle DISABLE ROW LEVEL SECURITY;
ALTER TABLE nft_master DISABLE ROW LEVEL SECURITY;
ALTER TABLE email_recipients DISABLE ROW LEVEL SECURITY;
ALTER TABLE system_emails DISABLE ROW LEVEL SECURITY;

-- 全削除
DELETE FROM email_recipients;
DELETE FROM system_emails;
DELETE FROM monthly_reward_tasks;
DELETE FROM monthly_withdrawals;
DELETE FROM buyback_requests;
DELETE FROM user_referral_profit;
DELETE FROM nft_referral_profit;
DELETE FROM nft_daily_profit;
DELETE FROM nft_holdings;
DELETE FROM nft_master;
DELETE FROM purchases;
DELETE FROM affiliate_cycle;
DELETE FROM users;
DELETE FROM admins;

SET session_replication_role = DEFAULT;

-- 確認
SELECT
    (SELECT COUNT(*) FROM admins) as admins,
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM affiliate_cycle) as cycles,
    (SELECT COUNT(*) FROM purchases) as purchases,
    (SELECT COUNT(*) FROM nft_master) as nfts;
