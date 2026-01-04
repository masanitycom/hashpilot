-- ========================================
-- 1/1の欠けている2NFTの日利レコードを追加
-- ========================================

-- 確認
SELECT '=== 追加対象のNFT ===' as section;
SELECT
  nm.id as nft_id,
  nm.user_id,
  nm.nft_type,
  nm.acquired_date
FROM nft_master nm
WHERE nm.id IN (
  'f7961807-b86a-4a35-83a4-1aff79cffc7e',  -- 59C23C
  '7a61c256-76f4-45ec-b664-cb004104b330'   -- A94B2B
);

-- profit_per_nft = 2500 / 1042 = 2.39923...
SELECT '=== 追加実行 ===' as section;

INSERT INTO nft_daily_profit (nft_id, user_id, date, daily_profit)
VALUES
  ('f7961807-b86a-4a35-83a4-1aff79cffc7e', '59C23C', '2026-01-01', 2500.0 / 1042),
  ('7a61c256-76f4-45ec-b664-cb004104b330', 'A94B2B', '2026-01-01', 2500.0 / 1042);

-- 確認
SELECT '=== 追加後確認 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(daily_profit) as total_profit,
  2500.0 as expected
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- affiliate_cycleに追加（この2ユーザーのavailable_usdtに加算）
SELECT '=== affiliate_cycle更新 ===' as section;

UPDATE affiliate_cycle
SET available_usdt = available_usdt + (2500.0 / 1042)
WHERE user_id IN ('59C23C', 'A94B2B');

-- 確認
SELECT user_id, available_usdt
FROM affiliate_cycle
WHERE user_id IN ('59C23C', 'A94B2B');
