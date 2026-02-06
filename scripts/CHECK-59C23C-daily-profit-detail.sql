-- ========================================
-- 59C23Cの1月日利詳細
-- ========================================

-- 1. NFTごとの日利レコード（1月）
SELECT '=== 1月日利詳細（NFTごと） ===' as section;
SELECT 
  date,
  nft_id,
  daily_profit
FROM nft_daily_profit
WHERE user_id = '59C23C'
  AND date >= '2026-01-01' AND date <= '2026-01-31'
ORDER BY date, nft_id;

-- 2. 日付別の集計
SELECT '=== 日付別集計 ===' as section;
SELECT 
  date,
  COUNT(*) as nft_count,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id = '59C23C'
  AND date >= '2026-01-01' AND date <= '2026-01-31'
GROUP BY date
ORDER BY date;

-- 3. NFT2（自動付与）のレコード確認
SELECT '=== NFT2のID確認 ===' as section;
SELECT id, user_id, nft_sequence, nft_type, operation_start_date
FROM nft_master
WHERE user_id = '59C23C';

-- 4. 1/1〜1/14にNFT2の日利があるか確認
SELECT '=== 1/1-1/14のNFT別レコード数 ===' as section;
SELECT 
  nft_id,
  COUNT(*) as record_count,
  MIN(date) as first_date,
  MAX(date) as last_date
FROM nft_daily_profit
WHERE user_id = '59C23C'
  AND date >= '2026-01-01' AND date <= '2026-01-14'
GROUP BY nft_id;
