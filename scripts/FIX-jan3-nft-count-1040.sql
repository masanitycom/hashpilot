-- ========================================
-- 1/3のNFT数を1040に修正
-- ========================================

-- 修正前確認
SELECT '=== 修正前: 1/3のデータ ===' as section;
SELECT date, total_nft_count, profit_per_nft, total_profit_amount
FROM daily_yield_log_v2
WHERE date = '2026-01-03';

-- 1. daily_yield_log_v2を修正
UPDATE daily_yield_log_v2
SET total_nft_count = 1040,
    profit_per_nft = total_profit_amount / 1040
WHERE date = '2026-01-03';

-- 2. 59C23CとA94B2Bの余分なnft_daily_profitを削除
-- まず対象NFTを確認
SELECT '=== 削除対象NFT ===' as section;
SELECT
  ndp.id,
  ndp.nft_id,
  nm.user_id,
  ndp.daily_profit
FROM nft_daily_profit ndp
JOIN nft_master nm ON ndp.nft_id = nm.id
WHERE nm.user_id IN ('59C23C', 'A94B2B')
  AND ndp.date = '2026-01-03';

-- 削除実行
DELETE FROM nft_daily_profit
WHERE date = '2026-01-03'
  AND nft_id IN (
    SELECT nm.id FROM nft_master nm
    JOIN users u ON nm.user_id = u.user_id
    WHERE u.operation_start_date > '2026-01-03'
      AND nm.buyback_date IS NULL
  );

-- 3. 残りのNFTの日利を再計算（マージン適用済み）
-- profit_per_nft × 0.7 × 0.6 = ユーザー受取額
SELECT '=== 修正前のnft_daily_profit ===' as section;
SELECT COUNT(*) as count, SUM(daily_profit) as total
FROM nft_daily_profit
WHERE date = '2026-01-03';

UPDATE nft_daily_profit
SET daily_profit = (SELECT total_profit_amount / 1040 FROM daily_yield_log_v2 WHERE date = '2026-01-03') * 0.7 * 0.6
WHERE date = '2026-01-03';

-- 修正後確認
SELECT '=== 修正後: 1/3のデータ ===' as section;
SELECT date, total_nft_count, profit_per_nft, total_profit_amount
FROM daily_yield_log_v2
WHERE date = '2026-01-03';

SELECT '=== 修正後のnft_daily_profit ===' as section;
SELECT COUNT(*) as count, SUM(daily_profit) as total, AVG(daily_profit) as avg_per_nft
FROM nft_daily_profit
WHERE date = '2026-01-03';

-- 4. affiliate_cycleの調整（余分に配布した分を引く）
SELECT '=== affiliate_cycle調整対象 ===' as section;
SELECT
  ac.user_id,
  ac.available_usdt,
  (SELECT SUM(daily_profit) FROM nft_daily_profit ndp
   JOIN nft_master nm ON ndp.nft_id = nm.id
   WHERE nm.user_id = ac.user_id AND ndp.date = '2026-01-03') as jan3_profit
FROM affiliate_cycle ac
WHERE ac.user_id IN ('59C23C', 'A94B2B');
