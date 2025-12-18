-- ========================================
-- 59C23Cのavailable_usdtを修正
-- ========================================
-- 11月に$1,132.01を出金済み（個人利益$32.01 + 紹介報酬$1,100）
-- 12月の日利: $7.44
-- available_usdt = 12月の日利のみ = $7.44

-- 修正前確認
SELECT '【修正前】' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  withdrawn_referral_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 12月の日利を取得
SELECT '【12月の日利】' as section;
SELECT
  user_id,
  SUM(daily_profit) as december_profit
FROM nft_daily_profit
WHERE user_id = '59C23C'
  AND date >= '2025-12-01'
GROUP BY user_id;

-- available_usdtを12月の日利に修正
UPDATE affiliate_cycle
SET available_usdt = (
  SELECT COALESCE(SUM(daily_profit), 0)
  FROM nft_daily_profit
  WHERE user_id = '59C23C'
    AND date >= '2025-12-01'
)
WHERE user_id = '59C23C';

-- 修正後確認
SELECT '【修正後】' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  withdrawn_referral_usdt,
  cum_usdt - withdrawn_referral_usdt as hold中の紹介報酬,
  phase
FROM affiliate_cycle
WHERE user_id = '59C23C';
