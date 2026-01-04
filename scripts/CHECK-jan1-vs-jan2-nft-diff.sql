-- ========================================
-- 1/1と1/2のNFT差を調査
-- ========================================

-- 1/1時点の運用中NFT数
SELECT '=== 1/1運用中NFT ===' as section;
SELECT COUNT(*) as jan1_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 1/2時点の運用中NFT数  
SELECT '=== 1/2運用中NFT ===' as section;
SELECT COUNT(*) as jan2_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- operation_start_date が 2026-01-01 または 2026-01-02 のユーザー
SELECT '=== operation_start_date 2026-01-01~02 ===' as section;
SELECT
  u.user_id,
  u.operation_start_date,
  COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IN ('2026-01-01', '2026-01-02')
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
GROUP BY u.user_id, u.operation_start_date
ORDER BY u.operation_start_date, u.user_id;
