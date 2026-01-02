-- ========================================
-- ACACDB のNFT取得履歴と日利レコード調査
-- ========================================

-- 1. 現在のNFT保有数
SELECT '=== 1. ACACDB: 現在のNFT保有数 ===' as section;
SELECT
  user_id,
  COUNT(*) as nft_count
FROM nft_master
WHERE user_id = 'ACACDB'
  AND buyback_date IS NULL
GROUP BY user_id;

-- 2. NFT取得日別の内訳
SELECT '=== 2. ACACDB: NFT取得日別 ===' as section;
SELECT
  acquired_date,
  COUNT(*) as nft_count
FROM nft_master
WHERE user_id = 'ACACDB'
  AND buyback_date IS NULL
GROUP BY acquired_date
ORDER BY acquired_date;

-- 3. 日利レコードの日別カウント
SELECT '=== 3. ACACDB: 日利レコード数/日 ===' as section;
SELECT
  date,
  COUNT(*) as record_count,
  SUM(daily_profit) as daily_total
FROM nft_daily_profit
WHERE user_id = 'ACACDB'
GROUP BY date
ORDER BY date;

-- 4. 日利の合計
SELECT '=== 4. ACACDB: 日利の総合計 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id = 'ACACDB';

-- 5. 紹介報酬の合計
SELECT '=== 5. ACACDB: 紹介報酬の総合計 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(profit_amount) as total_referral
FROM user_referral_profit_monthly
WHERE user_id = 'ACACDB';

-- 6. affiliate_cycleの現在値
SELECT '=== 6. ACACDB: affiliate_cycle ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id = 'ACACDB';

-- 7. 計算確認
SELECT '=== 7. ACACDB: 差額の計算 ===' as section;
SELECT
  ac.available_usdt as current_available,
  COALESCE(dp.total, 0) as daily_profit_total,
  COALESCE(rp.total, 0) as referral_total,
  COALESCE(dp.total, 0) + COALESCE(rp.total, 0) as expected,
  ac.available_usdt - (COALESCE(dp.total, 0) + COALESCE(rp.total, 0)) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  WHERE user_id = 'ACACDB'
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM user_referral_profit_monthly
  WHERE user_id = 'ACACDB'
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ac.user_id = 'ACACDB';

-- 8. 購入履歴
SELECT '=== 8. ACACDB: 購入履歴 ===' as section;
SELECT
  id,
  amount_usd,
  admin_approved,
  approved_at,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id = 'ACACDB'
ORDER BY created_at;
