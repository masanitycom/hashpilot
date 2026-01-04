-- ========================================
-- 1/3の余分な2つのnft_daily_profitを削除
-- ========================================

-- 削除前確認
SELECT '=== 削除対象 ===' as section;
SELECT
  ndp.id,
  ndp.nft_id,
  nm.user_id,
  nm.operation_start_date,
  ndp.daily_profit
FROM nft_daily_profit ndp
JOIN nft_master nm ON ndp.nft_id = nm.id
WHERE ndp.date = '2026-01-03'
  AND nm.operation_start_date > '2026-01-03';

-- 削除前のavailable_usdt
SELECT '=== 削除前 affiliate_cycle ===' as section;
SELECT user_id, available_usdt
FROM affiliate_cycle
WHERE user_id IN ('59C23C', 'A94B2B');

-- 削除実行
DELETE FROM nft_daily_profit
WHERE date = '2026-01-03'
  AND nft_id IN (
    SELECT nm.id FROM nft_master nm
    WHERE nm.operation_start_date > '2026-01-03'
  );

-- affiliate_cycleの調整（余分に配布した日利を引く）
-- 59C23C: 1/15運用開始のNFTに$3.708配布された
UPDATE affiliate_cycle
SET available_usdt = available_usdt - 3.708
WHERE user_id = '59C23C';

-- A94B2B: 1/15運用開始のNFTに$3.708配布された
UPDATE affiliate_cycle
SET available_usdt = available_usdt - 3.708
WHERE user_id = 'A94B2B';

-- 削除後確認
SELECT '=== 削除後 nft_daily_profit ===' as section;
SELECT date, COUNT(*) as nft_count
FROM nft_daily_profit
WHERE date >= '2026-01-01' AND date <= '2026-01-03'
GROUP BY date
ORDER BY date;

SELECT '=== 削除後 affiliate_cycle ===' as section;
SELECT user_id, available_usdt
FROM affiliate_cycle
WHERE user_id IN ('59C23C', 'A94B2B');
