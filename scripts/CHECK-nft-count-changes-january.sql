-- ========================================
-- NFT数変動の原因調査（2026年1月）
-- ========================================

-- 1. daily_yield_log_v2のNFT数履歴
SELECT '=== 1. 日利ログのNFT数履歴 ===' as section;
SELECT
  date,
  total_nft_count,
  total_profit_amount,
  profit_per_nft,
  created_at
FROM daily_yield_log_v2
WHERE date >= '2026-01-01'
ORDER BY date;

-- 2. 現在の運用中NFT数（ペガサス除く）
SELECT '=== 2. 現在の運用中NFT数 ===' as section;
SELECT COUNT(*) as 運用中NFT数
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= CURRENT_DATE
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 3. 日別の運用開始NFT数
SELECT '=== 3. 日別の運用開始NFT数（1月） ===' as section;
SELECT
  nm.operation_start_date,
  COUNT(*) as 運用開始NFT数
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date >= '2026-01-01'
  AND nm.operation_start_date <= '2026-01-31'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
GROUP BY nm.operation_start_date
ORDER BY nm.operation_start_date;

-- 4. 1/14, 1/15, 1/20の運用開始NFTの詳細
SELECT '=== 4. 1/14, 1/15, 1/20の運用開始NFT詳細 ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.operation_start_date,
  nm.acquired_date,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IN ('2026-01-14', '2026-01-15', '2026-01-20')
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
ORDER BY nm.operation_start_date, nm.user_id;

-- 5. 累積NFT数の推移（各日付時点での運用中NFT数）
SELECT '=== 5. 各日付時点での累積運用中NFT数 ===' as section;
WITH dates AS (
  SELECT generate_series('2026-01-01'::date, '2026-01-27'::date, '1 day'::interval)::date as d
)
SELECT
  dates.d as 日付,
  COUNT(nm.id) as 運用中NFT数
FROM dates
LEFT JOIN nft_master nm ON nm.operation_start_date <= dates.d AND nm.buyback_date IS NULL
LEFT JOIN users u ON nm.user_id = u.user_id
WHERE (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL OR u.user_id IS NULL)
GROUP BY dates.d
ORDER BY dates.d;

-- 6. operation_start_dateが未設定のNFT
SELECT '=== 6. operation_start_date未設定のNFT ===' as section;
SELECT
  nm.user_id,
  nm.acquired_date,
  nm.nft_type,
  nm.operation_start_date,
  u.email
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NULL
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 7. 1月に解約（buyback）されたNFT
SELECT '=== 7. 1月に解約されたNFT ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.acquired_date,
  nm.buyback_date,
  nm.operation_start_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date >= '2026-01-01'
ORDER BY nm.buyback_date;
