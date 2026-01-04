-- ========================================
-- NFTの運用開始日状況確認
-- ========================================

-- 1. 全体統計
SELECT '=== NFT全体統計 ===' as section;
SELECT
  COUNT(*) as total_active_nfts,
  COUNT(CASE WHEN nm.operation_start_date <= '2026-01-01' THEN 1 END) as operating_on_jan1,
  COUNT(CASE WHEN nm.operation_start_date <= '2026-01-03' THEN 1 END) as operating_on_jan3,
  COUNT(CASE WHEN nm.operation_start_date > '2026-01-03' THEN 1 END) as not_yet_operating
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 2. 1/1時点で運用中のNFT数
SELECT '=== 1/1時点の運用中NFT ===' as section;
SELECT COUNT(*) as nft_count_jan1
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 3. 9DDF45の状況（20個持っている）
SELECT '=== 9DDF45の詳細 ===' as section;
SELECT
  nm.id as nft_id,
  nm.acquired_date,
  nm.operation_start_date,
  nm.nft_type
FROM nft_master nm
WHERE nm.user_id = '9DDF45'
  AND nm.buyback_date IS NULL
ORDER BY nm.acquired_date;

-- 4. 59C23CとA94B2Bの詳細
SELECT '=== 59C23CとA94B2Bの詳細 ===' as section;
SELECT
  nm.user_id,
  nm.id as nft_id,
  nm.acquired_date,
  nm.operation_start_date,
  nm.nft_type
FROM nft_master nm
WHERE nm.user_id IN ('59C23C', 'A94B2B')
  AND nm.buyback_date IS NULL
ORDER BY nm.user_id, nm.acquired_date;

-- 5. 1/1〜1/3の日利ログのNFT数
SELECT '=== 1/1〜1/3の日利ログ ===' as section;
SELECT date, total_nft_count
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-03'
ORDER BY date;

-- 6. 各日のnft_daily_profitレコード数
SELECT '=== 各日のnft_daily_profitレコード数 ===' as section;
SELECT date, COUNT(*) as nft_count
FROM nft_daily_profit
WHERE date >= '2026-01-01' AND date <= '2026-01-03'
GROUP BY date
ORDER BY date;
