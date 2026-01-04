-- NFT数の不一致を調査（v2）

-- 1. 運用中NFT（条件：is_active_investor = true）
SELECT
    COUNT(*) as nft_count,
    '運用中（is_active_investor = true のみ）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_active_investor = true;

-- 2. is_active_investor = false のNFT数
SELECT
    COUNT(*) as nft_count,
    'is_active_investor = false' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_active_investor = false OR u.is_active_investor IS NULL);

-- 3. ペガサスユーザーのNFT数
SELECT
    COUNT(*) as nft_count,
    'ペガサスユーザー（is_pegasus = true）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_pegasus = true;

-- 4. 運用中NFT（ペガサス除外）
SELECT
    COUNT(*) as nft_count,
    '運用中（ペガサス除外）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus = false OR u.is_pegasus IS NULL);

-- 5. 運用中NFT（ペガサス除外 + is_active_investor = true）
SELECT
    COUNT(*) as nft_count,
    '運用中（ペガサス除外 + is_active_investor = true）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus = false OR u.is_pegasus IS NULL)
  AND u.is_active_investor = true;

-- 6. daily_yield_log_v2の1/2分のNFT数
SELECT total_nft_count FROM daily_yield_log_v2 WHERE date = '2026-01-02';

-- 7. 全条件の内訳
SELECT
    u.is_active_investor,
    u.is_pegasus,
    COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
GROUP BY u.is_active_investor, u.is_pegasus
ORDER BY u.is_active_investor, u.is_pegasus;
