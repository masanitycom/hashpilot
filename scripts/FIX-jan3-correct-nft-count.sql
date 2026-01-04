-- ========================================
-- 1/3のNFT数を正しく修正
-- ========================================
-- 運用開始日が1/3以降のNFTを除外

-- 修正前確認
SELECT '=== 修正前: 1/3のデータ ===' as section;
SELECT date, total_nft_count, profit_per_nft, total_profit_amount
FROM daily_yield_log_v2
WHERE date = '2026-01-03';

-- 運用中NFT数を計算（operation_start_date <= 1/3のNFTのみ）
SELECT '=== 運用中NFT数（1/3時点）===' as section;
SELECT COUNT(*) as correct_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-03'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 除外すべきNFT一覧
SELECT '=== 除外すべきNFT（operation_start_date > 1/3）===' as section;
SELECT
  nm.user_id,
  nm.id as nft_id,
  nm.acquired_date,
  nm.operation_start_date,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date > '2026-01-03'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
ORDER BY nm.user_id, nm.acquired_date;

-- 削除対象のnft_daily_profit
SELECT '=== 削除対象のnft_daily_profit（1/3）===' as section;
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

-- 削除実行
DELETE FROM nft_daily_profit
WHERE date = '2026-01-03'
  AND nft_id IN (
    SELECT nm.id FROM nft_master nm
    WHERE nm.operation_start_date > '2026-01-03'
      AND nm.buyback_date IS NULL
  );

-- daily_yield_log_v2を更新
-- 正しいNFT数を取得
WITH correct_count AS (
  SELECT COUNT(*) as cnt
  FROM nft_master nm
  JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND nm.operation_start_date IS NOT NULL
    AND nm.operation_start_date <= '2026-01-03'
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
)
UPDATE daily_yield_log_v2
SET total_nft_count = (SELECT cnt FROM correct_count),
    profit_per_nft = total_profit_amount / (SELECT cnt FROM correct_count)
WHERE date = '2026-01-03';

-- nft_daily_profitの日利を再計算（マージン適用）
UPDATE nft_daily_profit
SET daily_profit = (
  SELECT (total_profit_amount / total_nft_count) * 0.7 * 0.6
  FROM daily_yield_log_v2
  WHERE date = '2026-01-03'
)
WHERE date = '2026-01-03';

-- affiliate_cycleの調整（余分に配布した分を引く）
-- 対象ユーザーと削除された日利額を取得
SELECT '=== affiliate_cycle調整 ===' as section;

-- 59C23Cの調整（余分に受け取った日利を引く）
-- 注意: 59C23Cは2つのNFTがあり、1つは1/15運用開始（自動NFT）
UPDATE affiliate_cycle
SET available_usdt = available_usdt - (
  SELECT COALESCE(SUM(3.708), 0)  -- 削除された日利額（1 NFT分）
)
WHERE user_id = '59C23C';

-- A94B2Bの調整
UPDATE affiliate_cycle
SET available_usdt = available_usdt - (
  SELECT COALESCE(SUM(3.708), 0)  -- 削除された日利額（1 NFT分）
)
WHERE user_id = 'A94B2B';

-- 修正後確認
SELECT '=== 修正後: 1/3のデータ ===' as section;
SELECT date, total_nft_count, profit_per_nft, total_profit_amount
FROM daily_yield_log_v2
WHERE date = '2026-01-03';

SELECT '=== 修正後のnft_daily_profit ===' as section;
SELECT COUNT(*) as count, SUM(daily_profit) as total, AVG(daily_profit) as avg_per_nft
FROM nft_daily_profit
WHERE date = '2026-01-03';

-- 1/1〜1/3の比較
SELECT '=== 1/1〜1/3の比較（修正後）===' as section;
SELECT date, total_nft_count, profit_per_nft, total_profit_amount
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-03'
ORDER BY date;
