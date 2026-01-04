-- operation_start_dateが間違っている可能性のあるユーザーを確認
-- 2025年10月以前にNFT取得 → operation_start_date は 2025-11-01 であるべき

-- 1. 2025年10月以前にNFT取得なのに operation_start_date が 2025-11-01 以外のユーザー
SELECT
    u.user_id,
    u.operation_start_date,
    nm.acquired_date,
    nm.nft_type,
    u.is_pegasus_exchange
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.acquired_date <= '2025-10-31'
  AND nm.buyback_date IS NULL
  AND u.operation_start_date != '2025-11-01'
ORDER BY nm.acquired_date;

-- 2. 上記ユーザーの数
SELECT
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.acquired_date <= '2025-10-31'
  AND nm.buyback_date IS NULL
  AND u.operation_start_date != '2025-11-01';

-- 3. operation_start_dateの分布（10月以前NFT取得者）
SELECT
    u.operation_start_date,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.acquired_date <= '2025-10-31'
  AND nm.buyback_date IS NULL
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;
