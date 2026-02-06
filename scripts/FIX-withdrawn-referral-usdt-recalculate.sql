-- ========================================
-- withdrawn_referral_usdtの再計算
-- ========================================
-- 問題: referral_amountが記録されているが、
--       total_amountに含まれていない（実際には出金されていない）
-- 解決: total_amount - personal_amount で実際の紹介報酬出金額を計算
-- ========================================

-- STEP 0: 不整合データの確認
SELECT '=== STEP 0: 不整合データ確認 ===' as section;
SELECT
  user_id,
  created_at::date as withdrawal_date,
  personal_amount,
  referral_amount,
  total_amount,
  ROUND((total_amount - COALESCE(personal_amount, 0))::numeric, 2) as "実際の紹介報酬出金",
  CASE 
    WHEN ABS(COALESCE(referral_amount, 0) - (total_amount - COALESCE(personal_amount, 0))) > 1 
    THEN '不整合'
    ELSE 'OK'
  END as status
FROM monthly_withdrawals
WHERE status = 'completed'
  AND COALESCE(referral_amount, 0) > 0
  AND ABS(COALESCE(referral_amount, 0) - (total_amount - COALESCE(personal_amount, 0))) > 1
ORDER BY user_id, created_at;

-- STEP 1: 177B83の確認
SELECT '=== 177B83の出金履歴 ===' as section;
SELECT
  created_at::date as date,
  personal_amount,
  referral_amount as "記録された紹介報酬",
  total_amount,
  ROUND((total_amount - COALESCE(personal_amount, 0))::numeric, 2) as "実際の紹介報酬出金"
FROM monthly_withdrawals
WHERE user_id = '177B83'
  AND status = 'completed'
ORDER BY created_at;

-- STEP 2: withdrawn_referral_usdtを正しく再計算
SELECT '=== STEP 2: withdrawn_referral_usdt再計算 ===' as section;

UPDATE affiliate_cycle ac
SET
  withdrawn_referral_usdt = COALESCE(w.actual_referral_withdrawn, 0),
  updated_at = NOW()
FROM (
  SELECT 
    user_id,
    SUM(GREATEST(0, total_amount - COALESCE(personal_amount, 0))) as actual_referral_withdrawn
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w
WHERE ac.user_id = w.user_id;

-- STEP 3: 修正後の確認（自動NFTユーザー）
SELECT '=== STEP 3: 修正後の状態 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt(日利)",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt(紹介累計)",
  ac.phase,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "出金済み紹介報酬",
  ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能紹介報酬",
  ROUND((
    ac.available_usdt + 
    CASE WHEN ac.phase = 'USDT' 
      THEN GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0)) 
      ELSE 0 
    END
  )::numeric, 2) as "合計出金可能額"
FROM affiliate_cycle ac
WHERE ac.user_id IN ('177B83', '59C23C')
ORDER BY ac.user_id;

SELECT '✅ withdrawn_referral_usdt再計算完了' as status;
