-- ========================================
-- 1/1の欠けている59C23CのNFT日利レコードを追加
-- ========================================
-- A94B2Bは追加購入NFTで運用開始は1/15なので対象外

-- 確認
SELECT '=== 追加対象のNFT ===' as section;
SELECT
  nm.id as nft_id,
  nm.user_id,
  nm.nft_type,
  nm.acquired_date,
  u.operation_start_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.id = 'f7961807-b86a-4a35-83a4-1aff79cffc7e';

-- 追加実行
SELECT '=== 追加実行 ===' as section;

INSERT INTO nft_daily_profit (nft_id, user_id, date, daily_profit)
VALUES
  ('f7961807-b86a-4a35-83a4-1aff79cffc7e', '59C23C', '2026-01-01', 2500.0 / 1042);

-- 確認
SELECT '=== 追加後確認 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- affiliate_cycle更新
SELECT '=== affiliate_cycle更新 ===' as section;

UPDATE affiliate_cycle
SET available_usdt = available_usdt + (2500.0 / 1042)
WHERE user_id = '59C23C';

SELECT user_id, available_usdt
FROM affiliate_cycle
WHERE user_id = '59C23C';
