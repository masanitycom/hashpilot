-- ========================================
-- 1/1のNFT数を1040に戻す（修正の取り消し）
-- ========================================
-- 1/1時点の運用中NFT = 1040が正しい
-- - 59C23Cの自動付与NFT → 1/15から運用開始
-- - A94B2Bの追加購入NFT → 1/15から運用開始

-- ========================================
-- STEP 1: daily_yield_log_v2を1040に戻す
-- ========================================
SELECT '=== STEP 1: daily_yield_log_v2を修正 ===' as section;

UPDATE daily_yield_log_v2
SET
  total_nft_count = 1040,
  profit_per_nft = total_profit_amount / 1040
WHERE date = '2026-01-01';

SELECT date, total_nft_count, profit_per_nft FROM daily_yield_log_v2 WHERE date = '2026-01-01';

-- ========================================
-- STEP 2: nft_daily_profitを元の値に戻す
-- profit_per_nft = 2500 / 1040 = 2.4038...
-- ========================================
SELECT '=== STEP 2: nft_daily_profit修正 ===' as section;

UPDATE nft_daily_profit
SET daily_profit = 2500.0 / 1040
WHERE date = '2026-01-01';

SELECT
  COUNT(*) as records,
  SUM(daily_profit) as total,
  AVG(daily_profit) as avg_profit
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- ========================================
-- STEP 3: affiliate_cycleの調整を戻す
-- 先ほど減らした分を戻す
-- 差額: (2500/1040 - 2500/1042) × NFT数
-- ========================================
SELECT '=== STEP 3: affiliate_cycle調整を戻す ===' as section;

WITH adjustment AS (
  SELECT
    user_id,
    COUNT(*) as nft_count,
    COUNT(*) * (2500.0/1040 - 2500.0/1042) as add_back_amount
  FROM nft_daily_profit
  WHERE date = '2026-01-01'
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET available_usdt = ac.available_usdt + adj.add_back_amount
FROM adjustment adj
WHERE ac.user_id = adj.user_id;

-- ========================================
-- STEP 4: 確認
-- ========================================
SELECT '=== STEP 4: 最終確認 ===' as section;

SELECT
  (SELECT total_nft_count FROM daily_yield_log_v2 WHERE date = '2026-01-01') as log_nft_count,
  (SELECT COUNT(*) FROM nft_daily_profit WHERE date = '2026-01-01') as profit_records,
  (SELECT SUM(daily_profit) FROM nft_daily_profit WHERE date = '2026-01-01') as total_profit;
