-- affiliate_cycleテーブルの現在の状況確認

-- テーブル構造確認
SELECT 
    'affiliate_cycle structure' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'affiliate_cycle'
ORDER BY ordinal_position;

-- 現在のデータ状況
SELECT 
    'Current data summary' as info,
    COUNT(*) as total_users,
    COUNT(CASE WHEN total_nft_count > 0 THEN 1 END) as users_with_nft,
    SUM(total_nft_count) as total_nfts,
    AVG(cum_usdt) as avg_cum_usdt,
    COUNT(CASE WHEN cum_usdt >= 1100 AND cum_usdt < 2200 THEN 1 END) as hold_phase_users,
    COUNT(CASE WHEN cum_usdt >= 2200 THEN 1 END) as ready_for_auto_buy
FROM affiliate_cycle;

-- サンプルデータ
SELECT 
    'Sample data' as info,
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    cycle_start_date,
    last_updated
FROM affiliate_cycle 
WHERE total_nft_count > 0
ORDER BY cum_usdt DESC
LIMIT 10;