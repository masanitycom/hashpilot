-- ========================================
-- 59C23Cのwithdrawn_referral_usdtを修正
-- ========================================
-- 11月に紹介報酬$1,386.56を出金済みなので、
-- withdrawn_referral_usdtを更新する

-- 修正前確認
SELECT '【修正前】' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- withdrawn_referral_usdtを更新
UPDATE affiliate_cycle
SET withdrawn_referral_usdt = 1386.56
WHERE user_id = '59C23C';

-- 修正後確認
SELECT '【修正後】' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  cum_usdt - withdrawn_referral_usdt as remaining_referral
FROM affiliate_cycle
WHERE user_id = '59C23C';
