-- ========================================
-- ACBFBA 徹底調査
-- ========================================

-- 1. 11月の日利合計
SELECT '=== 11月日利合計 ===' as section;
SELECT COALESCE(SUM(daily_profit), 0) as nov_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
  AND date >= '2025-11-01' AND date < '2025-12-01';

-- 2. 12月の日利合計
SELECT '=== 12月日利合計 ===' as section;
SELECT COALESCE(SUM(daily_profit), 0) as dec_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
  AND date >= '2025-12-01' AND date < '2026-01-01';

-- 3. 全期間の日利合計
SELECT '=== 全期間日利合計 ===' as section;
SELECT COALESCE(SUM(daily_profit), 0) as all_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA';

-- 4. 日利レコード数（日付別）
SELECT '=== 日付別レコード数 ===' as section;
SELECT
  date,
  COUNT(*) as record_count,
  SUM(daily_profit) as daily_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
GROUP BY date
ORDER BY date;

-- 5. 紹介報酬（日次）
SELECT '=== 日次紹介報酬 ===' as section;
SELECT COALESCE(SUM(profit_amount), 0) as daily_referral_total
FROM user_referral_profit
WHERE user_id = 'ACBFBA';

-- 6. 紹介報酬（月次）
SELECT '=== 月次紹介報酬 ===' as section;
SELECT COALESCE(SUM(profit_amount), 0) as monthly_referral_total
FROM user_referral_profit_monthly
WHERE user_id = 'ACBFBA';

-- 7. available_usdtの内訳を推測
SELECT '=== available_usdt分析 ===' as section;
SELECT
  ac.available_usdt,
  COALESCE(dp.total_profit, 0) as all_daily_profit,
  COALESCE(rp.total_referral, 0) as all_referral_profit,
  ac.available_usdt - COALESCE(dp.total_profit, 0) - COALESCE(rp.total_referral, 0) as unknown_source
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE user_id = 'ACBFBA'
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit_monthly
  WHERE user_id = 'ACBFBA'
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ac.user_id = 'ACBFBA';

-- 8. daily_referral_profit（旧テーブル）確認
SELECT '=== daily_referral_profit確認 ===' as section;
SELECT COALESCE(SUM(referral_profit), 0) as old_referral_total
FROM daily_referral_profit
WHERE user_id = 'ACBFBA';

-- 9. stock_fund確認
SELECT '=== stock_fund確認 ===' as section;
SELECT COALESCE(SUM(stock_amount), 0) as stock_total
FROM stock_fund
WHERE user_id = 'ACBFBA';
