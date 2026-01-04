-- ========================================
-- operation_start_date = 2026-01-01 だが
-- 7月～10月にNFT取得したユーザーを修正
-- ========================================
-- システム運用開始日: 2025-11-01
-- 10月以前にNFT取得 → operation_start_date = 2025-11-01 であるべき
-- ========================================

-- ========================================
-- 1. 問題のあるユーザーを確認
-- ========================================
SELECT '=== 問題のあるユーザー（7月～10月取得だが2026-01-01運用開始） ===' as section;

SELECT
  u.user_id,
  u.operation_start_date,
  MIN(nm.acquired_date) as first_nft_acquired,
  COUNT(nm.id) as nft_count,
  '2025-11-01' as correct_operation_start
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date = '2026-01-01'
  AND nm.acquired_date < '2025-11-01'  -- 11月より前に取得
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
GROUP BY u.user_id, u.operation_start_date
ORDER BY MIN(nm.acquired_date);

-- ========================================
-- 2. 修正実行
-- ========================================
SELECT '=== operation_start_date を 2025-11-01 に修正 ===' as section;

UPDATE users
SET operation_start_date = '2025-11-01'
WHERE user_id IN (
  SELECT DISTINCT u.user_id
  FROM users u
  JOIN nft_master nm ON u.user_id = nm.user_id
  WHERE nm.buyback_date IS NULL
    AND u.operation_start_date = '2026-01-01'
    AND nm.acquired_date < '2025-11-01'
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
);

-- ========================================
-- 3. 修正後確認
-- ========================================
SELECT '=== 修正後確認 ===' as section;

SELECT
  user_id,
  operation_start_date
FROM users
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3');

-- ========================================
-- 4. 1/1のNFT数を修正
-- ========================================
SELECT '=== 1/1のdaily_yield_log_v2を修正 ===' as section;

-- まず正しいNFT数を確認
SELECT
  COUNT(*) as correct_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-01'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 1/1のレコードを更新
-- ⚠️ 注意: 上の確認結果を見てから実行
-- UPDATE daily_yield_log_v2
-- SET
--   total_nft_count = (正しいNFT数),
--   profit_per_nft = total_profit_amount / (正しいNFT数)
-- WHERE date = '2026-01-01';
