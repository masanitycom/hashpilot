-- ========================================
-- 1/1のNFT数を1040→1042に修正
-- ========================================
-- 問題: 1/1と1/2でNFT数が違う（1040 vs 1042）
-- 原因: 1日と15日以外でNFT数は変わらないはず
-- ========================================

-- ========================================
-- 1. 現状確認：daily_yield_log_v2の1月データ
-- ========================================
SELECT '=== 1月のdaily_yield_log_v2 ===' as section;

SELECT
  date,
  total_profit_amount,
  total_nft_count,
  profit_per_nft,
  created_at
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-31'
ORDER BY date;

-- ========================================
-- 2. 正しいNFT数を確認（2026-01-01時点）
-- ========================================
SELECT '=== 2026-01-01時点の正しいNFT数 ===' as section;

SELECT
  COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- ========================================
-- 3. 1/2時点のNFT数
-- ========================================
SELECT '=== 2026-01-02時点のNFT数 ===' as section;

SELECT
  COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- ========================================
-- 4. 1/1と1/2の間で運用開始したNFTがあるか確認
-- ========================================
SELECT '=== 1/1～1/2で運用開始したNFT ===' as section;

SELECT
  u.user_id,
  u.operation_start_date,
  nm.id as nft_id,
  nm.acquired_date
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date = '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
ORDER BY u.operation_start_date;

-- ========================================
-- 5. 問題の原因を特定：operation_start_date = 2026-01-01 のユーザー
-- ========================================
SELECT '=== operation_start_date = 2026-01-01 のユーザー ===' as section;

SELECT
  u.user_id,
  u.operation_start_date,
  COUNT(nm.id) as nft_count,
  MIN(nm.acquired_date) as first_nft_acquired
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date = '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
GROUP BY u.user_id, u.operation_start_date
ORDER BY u.user_id;

-- ========================================
-- 6. 修正：daily_yield_log_v2の1/1のNFT数を更新
-- ========================================
-- ⚠️ 注意: 実行前に上記の確認結果を見て、正しいNFT数を確認すること
-- ========================================
-- SELECT '=== 1/1のNFT数を修正 ===' as section;
--
-- 実際の修正は以下のようになる（コメントアウト中）
-- UPDATE daily_yield_log_v2
-- SET
--   total_nft_count = 1042,
--   profit_per_nft = total_profit_amount / 1042,
--   updated_at = NOW()
-- WHERE date = '2026-01-01';

-- ========================================
-- 7. 修正後の確認
-- ========================================
-- SELECT '=== 修正後の確認 ===' as section;
--
-- SELECT
--   date,
--   total_profit_amount,
--   total_nft_count,
--   profit_per_nft
-- FROM daily_yield_log_v2
-- WHERE date >= '2026-01-01' AND date <= '2026-01-02'
-- ORDER BY date;
