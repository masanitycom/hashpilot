-- 現在の運用中NFT数を確認

-- 1. 全NFT数（buyback_date IS NULL）
SELECT COUNT(*) as total_active_nft
FROM nft_master
WHERE buyback_date IS NULL;

-- 2. operation_start_dateの分布を確認
SELECT
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date DESC
LIMIT 30;

-- 3. operation_start_date >= 2024-12-01 のユーザーとNFT
SELECT
    u.user_id,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date >= '2024-12-01'
GROUP BY u.user_id, u.operation_start_date
ORDER BY u.operation_start_date DESC;

-- 4. daily_yield_log_v2の最新5件
SELECT
    yield_date,
    total_nft_count,
    daily_pnl,
    distribution_dividend
FROM daily_yield_log_v2
ORDER BY yield_date DESC
LIMIT 5;

-- 5. 59C23C（自動NFT付与ユーザー）の詳細
SELECT
    u.user_id,
    u.operation_start_date,
    nm.id,
    nm.acquired_date,
    nm.nft_type
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.user_id = '59C23C'
  AND nm.buyback_date IS NULL;

-- 6. 8BE74C（手動NFT追加ユーザー）の詳細
SELECT
    u.user_id,
    u.operation_start_date,
    nm.id,
    nm.acquired_date,
    nm.nft_type
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.user_id = '8BE74C'
  AND nm.buyback_date IS NULL;
