-- ========================================
-- 過剰額パターンの最終分析
-- ========================================
-- 修正前の過剰額リスト（記録から）:
-- ACACDB: $478.44 (12 NFT)
-- 264B91: $467.16
-- A6460E: $429.32
-- 1NFTユーザー多数: $23.912

-- 1. 1NFTあたりの過剰額を計算
SELECT '=== 1. 過剰額 ÷ NFT数 ===' as section;
SELECT
  478.44 / 12 as acacdb_per_nft,
  23.912 / 1 as one_nft_over,
  '1NFTあたり約$23.9〜$39.9の過剰' as note;

-- 2. 12月の日利合計（1NFTあたり）
SELECT '=== 2. 12月日利合計（1NFTあたり） ===' as section;
SELECT
  SUM(profit_per_nft * 0.42) as dec_profit_per_nft
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31';

-- 3. 月末処理前後の確認（12/31処理）
SELECT '=== 3. 月末紹介報酬処理の確認 ===' as section;
SELECT
  created_at,
  COUNT(*) as record_count,
  SUM(profit_amount) as total_amount
FROM user_referral_profit_monthly
GROUP BY created_at
ORDER BY created_at;

-- 4. affiliate_cycleの更新タイミング確認
SELECT '=== 4. affiliate_cycle更新日時（12月開始ユーザー） ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ac.available_usdt,
  ac.updated_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.operation_start_date = '2025-12-01'
ORDER BY ac.updated_at DESC
LIMIT 20;

-- 5. 月次紹介報酬が二重に加算された可能性
-- available_usdtへの加算が2回行われた？
SELECT '=== 5. 月次紹介報酬とcum_usdtの比較 ===' as section;
SELECT
  ac.user_id,
  ac.cum_usdt,
  COALESCE(mrp.total, 0) as monthly_referral_total,
  ac.cum_usdt - COALESCE(mrp.total, 0) as diff
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM user_referral_profit_monthly
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ABS(ac.cum_usdt - COALESCE(mrp.total, 0)) > 1
ORDER BY ABS(ac.cum_usdt - COALESCE(mrp.total, 0)) DESC
LIMIT 20;

-- 6. 日利が約2倍になっていたか確認
-- 12/1開始・1NFTユーザーの場合
-- 正しい日利: $23.408
-- 過剰額: $23.912
-- 合計で$47.32があったはず = 日利が2倍
SELECT '=== 6. 1NFTユーザーの日利倍率確認 ===' as section;
SELECT
  47.32 / 23.408 as ratio,
  '修正前available_usdt ÷ 正しい日利 = 約2倍' as note;

-- 7. process_daily_yield_v2の二重実行確認
SELECT '=== 7. daily_yield_log_v2の重複確認 ===' as section;
SELECT
  date,
  COUNT(*) as count
FROM daily_yield_log_v2
WHERE date >= '2025-12-01'
GROUP BY date
HAVING COUNT(*) > 1;

-- 8. nft_daily_profitの重複確認
SELECT '=== 8. nft_daily_profitの重複（同一NFT×日付） ===' as section;
SELECT
  nft_id,
  date,
  COUNT(*) as count
FROM nft_daily_profit
WHERE date >= '2025-12-01'
GROUP BY nft_id, date
HAVING COUNT(*) > 1
LIMIT 10;
