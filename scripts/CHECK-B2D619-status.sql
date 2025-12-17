-- B2D619ユーザーの状態確認

-- 基本情報
SELECT '【基本情報】' as section;
SELECT
  user_id,
  email,
  has_approved_nft,
  operation_start_date,
  is_pegasus_exchange,
  total_purchases
FROM users
WHERE user_id = 'B2D619';

-- NFT情報
SELECT '【NFT情報】' as section;
SELECT
  id,
  user_id,
  nft_type,
  nft_value,
  acquired_date,
  buyback_date
FROM nft_master
WHERE user_id = 'B2D619';

-- 日利配布履歴
SELECT '【日利配布履歴】' as section;
SELECT
  date,
  SUM(daily_profit) as daily_profit
FROM nft_daily_profit
WHERE user_id = 'B2D619'
GROUP BY date
ORDER BY date DESC;

-- affiliate_cycle情報
SELECT '【affiliate_cycle】' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  manual_nft_count,
  auto_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id = 'B2D619';

-- 12月の日利合計
SELECT '【12月の日利合計】' as section;
SELECT
  COUNT(*) as days_count,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id = 'B2D619'
  AND date >= '2025-12-01'
  AND date <= '2025-12-31';
