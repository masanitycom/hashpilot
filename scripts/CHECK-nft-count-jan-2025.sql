-- 2025年1月のNFT数を確認
-- 運用中NFT = operation_start_date <= 対象日 AND buyback_date IS NULL

-- 1. 各日付で運用中のNFT数
SELECT
    '2025-01-01' as target_date,
    '12/31分の日利' as description,
    COUNT(*) as operational_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-01-01'

UNION ALL

SELECT
    '2025-01-02' as target_date,
    '1/1分の日利' as description,
    COUNT(*) as operational_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-01-02'

UNION ALL

SELECT
    '2025-01-15' as target_date,
    '1/14分の日利' as description,
    COUNT(*) as operational_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-01-15'

UNION ALL

SELECT
    '2025-01-16' as target_date,
    '1/15分の日利' as description,
    COUNT(*) as operational_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-01-16'

ORDER BY target_date;

-- 2. operation_start_date = 1/1 のユーザーとNFT数
SELECT
    u.user_id,
    u.operation_start_date,
    COUNT(nm.id) as nft_count,
    nm.nft_type,
    nm.acquired_date
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2025-01-01'
  AND nm.buyback_date IS NULL
ORDER BY u.user_id;

-- 3. operation_start_date = 1/15 のユーザーとNFT数
SELECT
    u.user_id,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2025-01-15'
  AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.operation_start_date
ORDER BY u.user_id;

-- 4. daily_yield_log_v2で記録されたNFT数
SELECT
    yield_date,
    total_nft_count as logged_nft_count
FROM daily_yield_log_v2
WHERE yield_date >= '2024-12-31'
ORDER BY yield_date;

-- 5. 1/1に運用開始するユーザー（NFT取得日が12/16-12/20）
SELECT
    u.user_id,
    u.operation_start_date,
    nm.acquired_date,
    nm.nft_type
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2025-01-01'
  AND nm.buyback_date IS NULL
ORDER BY nm.acquired_date;

-- 6. 1/15に運用開始するユーザー（NFT取得日が12/21-12/31または1/6-1/20）
SELECT
    u.user_id,
    u.operation_start_date,
    nm.acquired_date,
    nm.nft_type
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2025-01-15'
  AND nm.buyback_date IS NULL
ORDER BY nm.acquired_date;
