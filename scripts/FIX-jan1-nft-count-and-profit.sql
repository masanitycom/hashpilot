-- ========================================
-- 1/1のNFT数修正と日利再配分
-- ========================================

-- ========================================
-- STEP 1: daily_yield_log_v2のNFT数を修正
-- ========================================
SELECT '=== STEP 1: daily_yield_log_v2修正 ===' as section;

-- 修正前
SELECT date, total_nft_count, profit_per_nft FROM daily_yield_log_v2 WHERE date = '2026-01-01';

-- 修正（updated_atカラムなし）
UPDATE daily_yield_log_v2
SET
  total_nft_count = 1042,
  profit_per_nft = total_profit_amount / 1042
WHERE date = '2026-01-01';

-- 修正後
SELECT date, total_nft_count, profit_per_nft FROM daily_yield_log_v2 WHERE date = '2026-01-01';

-- ========================================
-- STEP 2: 1/1のprofit_per_nftを確認
-- ========================================
SELECT '=== STEP 2: 新しいprofit_per_nft ===' as section;

SELECT
  date,
  total_profit_amount,
  total_nft_count,
  profit_per_nft,
  total_profit_amount::numeric / 1042 as calculated_profit_per_nft
FROM daily_yield_log_v2
WHERE date = '2026-01-01';

-- ========================================
-- STEP 3: nft_daily_profitの1/1を再計算
-- 新しいprofit_per_nft = $2500 / 1042 = $2.39923...
-- ========================================
SELECT '=== STEP 3: nft_daily_profit更新前（サンプル10件） ===' as section;

SELECT user_id, date, daily_profit
FROM nft_daily_profit
WHERE date = '2026-01-01'
ORDER BY user_id
LIMIT 10;

-- ========================================
-- STEP 4: 各ユーザーのNFT数を取得して再計算
-- ========================================
SELECT '=== STEP 4: nft_daily_profit再計算 ===' as section;

-- 新しいprofit_per_nft
WITH new_rate AS (
  SELECT 2500.0 / 1042 as profit_per_nft  -- $2.39923...
),
user_nft_counts AS (
  SELECT
    nm.user_id,
    COUNT(*) as nft_count
  FROM nft_master nm
  JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= '2026-01-01'
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
  GROUP BY nm.user_id
)
UPDATE nft_daily_profit ndp
SET daily_profit = unc.nft_count * nr.profit_per_nft
FROM user_nft_counts unc, new_rate nr
WHERE ndp.user_id = unc.user_id
  AND ndp.date = '2026-01-01';

-- ========================================
-- STEP 5: 更新後確認
-- ========================================
SELECT '=== STEP 5: 更新後確認（サンプル10件） ===' as section;

SELECT user_id, date, daily_profit
FROM nft_daily_profit
WHERE date = '2026-01-01'
ORDER BY user_id
LIMIT 10;

-- ========================================
-- STEP 6: 合計確認
-- ========================================
SELECT '=== STEP 6: 合計確認 ===' as section;

SELECT
  COUNT(*) as user_count,
  SUM(daily_profit) as total_distributed,
  2500.0 as expected_total
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- ========================================
-- STEP 7: affiliate_cycleのavailable_usdtも更新が必要
-- 差額を計算して調整
-- ========================================
SELECT '=== STEP 7: affiliate_cycle調整額計算 ===' as section;

-- 旧profit_per_nft = 2500/1040 = $2.4038...
-- 新profit_per_nft = 2500/1042 = $2.3992...
-- 差額 = 旧 - 新 = $0.0046... per NFT

WITH old_rate AS (SELECT 2500.0 / 1040 as profit_per_nft),
     new_rate AS (SELECT 2500.0 / 1042 as profit_per_nft),
     user_nft_counts AS (
       SELECT nm.user_id, COUNT(*) as nft_count
       FROM nft_master nm
       JOIN users u ON nm.user_id = u.user_id
       WHERE nm.buyback_date IS NULL
         AND u.operation_start_date IS NOT NULL
         AND u.operation_start_date <= '2026-01-01'
         AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
       GROUP BY nm.user_id
     )
SELECT
  unc.user_id,
  unc.nft_count,
  unc.nft_count * o.profit_per_nft as old_profit,
  unc.nft_count * n.profit_per_nft as new_profit,
  unc.nft_count * (o.profit_per_nft - n.profit_per_nft) as adjustment
FROM user_nft_counts unc, old_rate o, new_rate n
ORDER BY unc.nft_count DESC
LIMIT 10;

