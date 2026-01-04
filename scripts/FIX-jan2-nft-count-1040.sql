-- ========================================
-- 1/2のNFT数を1042→1040に修正
-- ========================================

-- STEP 1: daily_yield_log_v2修正
UPDATE daily_yield_log_v2
SET 
  total_nft_count = 1040,
  profit_per_nft = total_profit_amount / 1040
WHERE date = '2026-01-02';

-- STEP 2: 確認
SELECT date, total_nft_count, profit_per_nft
FROM daily_yield_log_v2
WHERE date IN ('2026-01-01', '2026-01-02')
ORDER BY date;

-- STEP 3: 余分な2NFTのnft_daily_profitを削除
-- 59C23Cの自動NFTとA94B2Bの追加NFT
DELETE FROM nft_daily_profit
WHERE date = '2026-01-02'
AND nft_id IN (
  'f7961807-b86a-4a35-83a4-1aff79cffc7e',  -- 59C23C auto
  '7a61c256-76f4-45ec-b664-cb004104b330'   -- A94B2B manual
);

-- STEP 4: 残りのNFTのprofit_per_nftを再計算
-- 新しいprofit_per_nft = 17500 / 1040 × 0.7 × 0.6
UPDATE nft_daily_profit
SET daily_profit = (17500.0 / 1040) * 0.7 * 0.6
WHERE date = '2026-01-02';

-- STEP 5: 確認
SELECT COUNT(*) as records, SUM(daily_profit) as total, AVG(daily_profit) as avg
FROM nft_daily_profit WHERE date = '2026-01-02';

-- STEP 6: affiliate_cycle調整（差額を引く）
WITH adjustment AS (
  SELECT user_id, COUNT(*) as nft_count,
    COUNT(*) * ((17500.0/1042 * 0.7 * 0.6) - (17500.0/1040 * 0.7 * 0.6)) as reduce
  FROM nft_daily_profit WHERE date = '2026-01-02'
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET available_usdt = ac.available_usdt - adj.reduce
FROM adjustment adj
WHERE ac.user_id = adj.user_id;
