-- ========================================
-- ペガサスユーザーのNFT運用開始日確認
-- ========================================

-- 1. ペガサスユーザーのNFT一覧
SELECT '=== 1. ペガサスユーザーのNFT（運用開始日順） ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.operation_start_date,
  nm.acquired_date,
  nm.nft_type,
  nm.buyback_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE u.is_pegasus_exchange = true
ORDER BY nm.operation_start_date;

-- 2. ペガサスユーザーのNFT数（日別）
SELECT '=== 2. ペガサスNFTの運用開始日別カウント ===' as section;
SELECT
  nm.operation_start_date,
  COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE u.is_pegasus_exchange = true
  AND nm.buyback_date IS NULL
GROUP BY nm.operation_start_date
ORDER BY nm.operation_start_date;

-- 3. 1/19と1/20の全NFT数比較（ペガサス含む）
SELECT '=== 3. 全NFT数（ペガサス含む） ===' as section;
SELECT
  '2026-01-19' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-19'
UNION ALL
SELECT
  '2026-01-20' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-20'
UNION ALL
SELECT
  '2026-01-21' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-21';

-- 4. 1/20に運用開始するNFT（全ユーザー）
SELECT '=== 4. 2026-01-20運用開始のNFT ===' as section;
SELECT
  nm.user_id,
  u.email,
  u.is_pegasus_exchange,
  nm.acquired_date,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.operation_start_date = '2026-01-20'
  AND nm.buyback_date IS NULL;

-- 5. 1/21に運用開始するNFT（全ユーザー）
SELECT '=== 5. 2026-01-21運用開始のNFT ===' as section;
SELECT
  nm.user_id,
  u.email,
  u.is_pegasus_exchange,
  nm.acquired_date,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.operation_start_date = '2026-01-21'
  AND nm.buyback_date IS NULL;

-- 6. 2/1に運用開始するNFT（全ユーザー、1/6-1/20承認分）
SELECT '=== 6. 2026-02-01運用開始のNFT ===' as section;
SELECT
  nm.user_id,
  u.email,
  u.is_pegasus_exchange,
  nm.acquired_date,
  nm.operation_start_date,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.operation_start_date = '2026-02-01'
  AND nm.buyback_date IS NULL
ORDER BY u.is_pegasus_exchange DESC, nm.user_id;
