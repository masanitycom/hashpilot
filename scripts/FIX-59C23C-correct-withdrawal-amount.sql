-- ========================================
-- 59C23Cの出金記録を正しく修正
-- ========================================
-- 実際の送金:
--   配当: $32.01
--   紹介報酬: $1,100（USDTフェーズ分のみ）
--   合計: $1,132.01
-- HOLD中: $286.56（未出金）

-- 修正前確認
SELECT '【修正前】monthly_withdrawals' as section;
SELECT
  user_id,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
  AND withdrawal_month = '2025-11-01';

SELECT '【修正前】affiliate_cycle' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 1. monthly_withdrawalsを修正
UPDATE monthly_withdrawals
SET
  referral_amount = 1100.00,
  total_amount = 32.01 + 1100.00  -- personal_amount + referral_amount
WHERE user_id = '59C23C'
  AND withdrawal_month = '2025-11-01';

-- 2. affiliate_cycleのwithdrawn_referral_usdtを修正
UPDATE affiliate_cycle
SET withdrawn_referral_usdt = 1100.00
WHERE user_id = '59C23C';

-- 修正後確認
SELECT '【修正後】monthly_withdrawals' as section;
SELECT
  user_id,
  personal_amount,
  referral_amount,
  total_amount,
  personal_amount + referral_amount as 計算合計,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
  AND withdrawal_month = '2025-11-01';

SELECT '【修正後】affiliate_cycle' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  cum_usdt - withdrawn_referral_usdt as 未出金紹介報酬
FROM affiliate_cycle
WHERE user_id = '59C23C';
