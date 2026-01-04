-- ========================================
-- 1/1の欠けているNFTレコードを調査
-- ========================================

-- 1. 1/1時点で運用中のNFT数
SELECT '=== 1/1時点で運用中のNFT数 ===' as section;
SELECT COUNT(*) as expected_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 2. 1/1のnft_daily_profitレコード数
SELECT '=== 1/1のnft_daily_profitレコード数 ===' as section;
SELECT COUNT(*) as actual_records FROM nft_daily_profit WHERE date = '2026-01-01';

-- 3. 欠けているNFTを特定
SELECT '=== 欠けているNFT（nft_daily_profitにない） ===' as section;
SELECT
  nm.id as nft_id,
  nm.user_id,
  nm.nft_type,
  nm.acquired_date,
  u.operation_start_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
  AND nm.id NOT IN (
    SELECT nft_id FROM nft_daily_profit WHERE date = '2026-01-01'
  )
ORDER BY nm.user_id;

-- 4. operation_start_date = 2026-01-01 のユーザーとNFT
SELECT '=== operation_start_date = 2026-01-01 のユーザー ===' as section;
SELECT
  u.user_id,
  u.operation_start_date,
  COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date = '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
GROUP BY u.user_id, u.operation_start_date
ORDER BY COUNT(nm.id) DESC;
