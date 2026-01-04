-- ========================================
-- 1/1のnft_daily_profit修正（正しい方法）
-- ========================================
-- nft_daily_profitはNFTごとに1レコード
-- 各レコードにprofit_per_nftをそのまま設定する

-- ========================================
-- STEP 1: 現状確認
-- ========================================
SELECT '=== 現状確認 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(daily_profit) as current_total,
  AVG(daily_profit) as current_avg
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- ========================================
-- STEP 2: 新しいprofit_per_nftで全レコード更新
-- ========================================
SELECT '=== STEP 2: 全レコード更新 ===' as section;

-- profit_per_nft = 2500 / 1042 = 2.39923...
UPDATE nft_daily_profit
SET daily_profit = 2500.0 / 1042
WHERE date = '2026-01-01';

-- ========================================
-- STEP 3: 更新後確認
-- ========================================
SELECT '=== 更新後確認 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(daily_profit) as new_total,
  AVG(daily_profit) as new_avg,
  2500.0 as expected_total
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- ========================================
-- STEP 4: サンプル確認
-- ========================================
SELECT '=== サンプル確認（02FDF0） ===' as section;
SELECT user_id, date, daily_profit
FROM nft_daily_profit
WHERE user_id = '02FDF0' AND date = '2026-01-01';

-- ========================================
-- STEP 5: affiliate_cycleの調整
-- 旧: 2500/1040 = 2.4038... per NFT
-- 新: 2500/1042 = 2.3992... per NFT
-- 差額: 0.0046... per NFT × NFT数 = 調整額
-- ========================================
SELECT '=== STEP 5: affiliate_cycle調整 ===' as section;

-- 差額計算: (2500/1040 - 2500/1042) = 0.00461...
WITH adjustment AS (
  SELECT
    user_id,
    COUNT(*) as nft_count,
    COUNT(*) * (2500.0/1040 - 2500.0/1042) as reduce_amount
  FROM nft_daily_profit
  WHERE date = '2026-01-01'
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET available_usdt = ac.available_usdt - adj.reduce_amount
FROM adjustment adj
WHERE ac.user_id = adj.user_id;

-- ========================================
-- STEP 6: 調整後確認（上位10件）
-- ========================================
SELECT '=== 調整後確認 ===' as section;
SELECT
  ac.user_id,
  ac.available_usdt
FROM affiliate_cycle ac
ORDER BY ac.available_usdt DESC
LIMIT 10;
