-- 全テーブルをクリア
SET session_replication_role = replica;

TRUNCATE TABLE 
  email_recipients,
  system_emails,
  monthly_reward_tasks,
  monthly_withdrawals,
  buyback_requests,
  user_referral_profit,
  nft_referral_profit,
  nft_daily_profit,
  nft_holdings,
  nft_master,
  purchases,
  affiliate_cycle,
  users,
  admins
CASCADE;

SET session_replication_role = DEFAULT;

-- 確認
SELECT
    (SELECT COUNT(*) FROM admins) as admins,
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM affiliate_cycle) as cycles,
    (SELECT COUNT(*) FROM purchases) as purchases,
    (SELECT COUNT(*) FROM nft_master) as nfts;
