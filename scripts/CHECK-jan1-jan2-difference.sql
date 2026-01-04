-- ========================================
-- 1/1と1/2の差のNFTを特定
-- ========================================

-- 1/2で運用中だが1/1で運用中でないNFT
SELECT '=== 1/2で追加されたNFT ===' as section;
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
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
  AND NOT (u.operation_start_date <= '2026-01-01')
ORDER BY u.operation_start_date;

-- operation_start_date = 2026-01-02 のユーザー
SELECT '=== operation_start_date = 2026-01-02 ===' as section;
SELECT
  u.user_id,
  u.operation_start_date,
  COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date = '2026-01-02'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
GROUP BY u.user_id, u.operation_start_date;
