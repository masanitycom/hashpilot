-- Phase 1で作成されたテーブルの確認
SELECT 'daily_yield_log' as table_name, COUNT(*) as count FROM daily_yield_log
UNION ALL
SELECT 'affiliate_cycle' as table_name, COUNT(*) as count FROM affiliate_cycle
UNION ALL
SELECT 'system_config' as table_name, COUNT(*) as count FROM system_config
UNION ALL
SELECT 'nft_holdings' as table_name, COUNT(*) as count FROM nft_holdings;

-- システム設定の確認
SELECT * FROM system_config;

-- NFT保有状況の確認
SELECT user_id, nft_type, purchase_amount, purchase_date FROM nft_holdings ORDER BY purchase_date DESC;

-- ユーザーサイクル状況の確認
SELECT user_id, phase, total_nft_count, cum_usdt FROM affiliate_cycle ORDER BY total_nft_count DESC;
