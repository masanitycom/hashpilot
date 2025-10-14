-- ========================================
-- 自動付与NFTへの日利反映を検証
-- ========================================

-- 1. 自動付与NFTの一覧
SELECT
    'auto NFT一覧' as section,
    nm.user_id,
    nm.id as nft_id,
    nm.nft_sequence,
    nm.nft_value,
    nm.acquired_date,
    COUNT(ndp.id) as profit_records,
    COALESCE(SUM(ndp.daily_profit), 0) as total_profit
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.nft_type = 'auto'
  AND nm.buyback_date IS NULL
GROUP BY nm.user_id, nm.id, nm.nft_sequence, nm.nft_value, nm.acquired_date
ORDER BY nm.acquired_date DESC, nm.user_id
LIMIT 20;

-- 2. 自動NFTと手動NFTの日利記録を比較
SELECT
    u.user_id,
    u.email,
    COUNT(DISTINCT CASE WHEN nm.nft_type = 'manual' THEN nm.id END) as manual_nft_count,
    COUNT(DISTINCT CASE WHEN nm.nft_type = 'auto' THEN nm.id END) as auto_nft_count,
    COUNT(DISTINCT CASE WHEN nm.nft_type = 'manual' THEN ndp.id END) as manual_profit_records,
    COUNT(DISTINCT CASE WHEN nm.nft_type = 'auto' THEN ndp.id END) as auto_profit_records,
    COALESCE(SUM(CASE WHEN nm.nft_type = 'manual' THEN ndp.daily_profit END), 0) as manual_total_profit,
    COALESCE(SUM(CASE WHEN nm.nft_type = 'auto' THEN ndp.daily_profit END), 0) as auto_total_profit
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
GROUP BY u.user_id, u.email
HAVING COUNT(DISTINCT CASE WHEN nm.nft_type = 'auto' THEN nm.id END) > 0
ORDER BY auto_nft_count DESC
LIMIT 10;

-- 3. 特定日の自動NFTへの日利配布状況
SELECT
    '2025-10-02の自動NFT日利' as section,
    nm.user_id,
    nm.id as nft_id,
    nm.nft_type,
    nm.nft_sequence,
    ndp.date,
    ndp.daily_profit,
    ndp.yield_rate
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id AND ndp.date = '2025-10-02'
WHERE nm.nft_type = 'auto'
  AND nm.buyback_date IS NULL
ORDER BY nm.user_id, nm.nft_sequence
LIMIT 20;

-- 4. 日利処理関数が自動NFTを対象に含めているか確認
SELECT
    '日利処理のNFT対象条件' as section,
    routine_definition LIKE '%nft_type%' as checks_nft_type,
    routine_definition LIKE '%buyback_date IS NULL%' as checks_buyback,
    routine_definition LIKE '%operation_start_date%' as checks_operation_start
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 5. 紹介報酬が自動NFT保有者に正しく配布されているか
SELECT
    '紹介報酬の確認' as section,
    u.user_id,
    ac.total_nft_count,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.cum_usdt as referral_reward_cumulative,
    ac.available_usdt as withdrawable_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.auto_nft_count DESC
LIMIT 10;
