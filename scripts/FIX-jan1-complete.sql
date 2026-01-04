-- ========================================
-- 1/1の完全修正（nft_daily_profit + affiliate_cycle）
-- ========================================

-- STEP 1: 修正前確認
SELECT '=== STEP 1: 修正前確認 ===' as section;
SELECT AVG(daily_profit) as avg_profit, SUM(daily_profit) as total
FROM nft_daily_profit WHERE date = '2026-01-01';

-- STEP 2: nft_daily_profitにマージン適用
-- $2.404 × 0.7 × 0.6 = $1.010
SELECT '=== STEP 2: nft_daily_profit修正 ===' as section;
UPDATE nft_daily_profit
SET daily_profit = daily_profit * 0.7 * 0.6
WHERE date = '2026-01-01';

SELECT AVG(daily_profit) as avg_profit, SUM(daily_profit) as total
FROM nft_daily_profit WHERE date = '2026-01-01';

-- STEP 3: affiliate_cycleのavailable_usdtから差額を引く
-- 差額 = $2.404 - $1.010 = $1.394 per NFT
SELECT '=== STEP 3: affiliate_cycle修正 ===' as section;

WITH user_adjustment AS (
  SELECT 
    user_id,
    SUM(daily_profit) as current_profit,
    SUM(daily_profit) / 0.42 as original_profit,  -- 0.42 = 0.7 * 0.6
    SUM(daily_profit) / 0.42 - SUM(daily_profit) as reduce_amount
  FROM nft_daily_profit
  WHERE date = '2026-01-01'
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET available_usdt = ac.available_usdt - ua.reduce_amount
FROM user_adjustment ua
WHERE ac.user_id = ua.user_id;

-- STEP 4: 確認
SELECT '=== STEP 4: 0D4493確認 ===' as section;
SELECT date, daily_profit
FROM nft_daily_profit
WHERE user_id = '0D4493' AND date >= '2026-01-01'
ORDER BY date;

SELECT '=== STEP 5: 合計確認 ===' as section;
SELECT 
  SUM(daily_profit) as jan1_total,
  (SELECT SUM(daily_profit) FROM nft_daily_profit WHERE date = '2026-01-02') as jan2_total
FROM nft_daily_profit WHERE date = '2026-01-01';
