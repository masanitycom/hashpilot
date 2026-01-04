-- NFT数の不一致を調査

-- 1. process_daily_yield_v2で使用しているNFT数の計算方法を再現
-- 運用中NFT = operation_start_date <= 対象日 AND buyback_date IS NULL AND is_active_investor = true
SELECT
    COUNT(*) as operational_nft_count_with_active,
    '運用中（is_active_investor = true）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_active_investor = true;

-- 2. is_active_investor = false のユーザーのNFT数
SELECT
    COUNT(*) as inactive_nft_count,
    'is_active_investor = false' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_active_investor = false;

-- 3. is_active_investor がNULLのユーザー
SELECT
    COUNT(*) as null_active_nft_count,
    'is_active_investor IS NULL' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_active_investor IS NULL;

-- 4. ペガサスユーザー（is_pegasus = true）のNFT数
SELECT
    COUNT(*) as pegasus_nft_count,
    'ペガサスユーザー' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_pegasus = true;

-- 5. 休眠ユーザー（is_dormant = true）のNFT数
SELECT
    COUNT(*) as dormant_nft_count,
    '休眠ユーザー' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_dormant = true;

-- 6. operation_start_dateが古すぎるユーザー（2025年7-8月にNFT取得なのに2026年1月運用開始）
SELECT
    u.user_id,
    u.operation_start_date,
    nm.acquired_date,
    u.is_active_investor,
    u.is_pegasus,
    u.is_dormant
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2026-01-01'
  AND nm.acquired_date < '2025-12-01'
  AND nm.buyback_date IS NULL
ORDER BY nm.acquired_date;

-- 7. 全ユーザーのis_active_investor分布
SELECT
    is_active_investor,
    COUNT(*) as user_count
FROM users
GROUP BY is_active_investor;
