-- ========================================
-- 1/1のNFT数を1042に修正（実行用）
-- ========================================

-- 修正前確認
SELECT '=== 修正前 ===' as section;
SELECT
  date,
  total_profit_amount,
  total_nft_count,
  profit_per_nft
FROM daily_yield_log_v2
WHERE date = '2026-01-01';

-- 修正実行
UPDATE daily_yield_log_v2
SET
  total_nft_count = 1042,
  profit_per_nft = total_profit_amount / 1042,
  updated_at = NOW()
WHERE date = '2026-01-01';

-- 修正後確認
SELECT '=== 修正後 ===' as section;
SELECT
  date,
  total_profit_amount,
  total_nft_count,
  profit_per_nft
FROM daily_yield_log_v2
WHERE date = '2026-01-01';

-- 1/1と1/2の比較
SELECT '=== 1/1と1/2の比較 ===' as section;
SELECT
  date,
  total_nft_count,
  profit_per_nft
FROM daily_yield_log_v2
WHERE date IN ('2026-01-01', '2026-01-02')
ORDER BY date;
