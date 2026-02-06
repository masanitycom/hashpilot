-- ========================================
-- HOLDフェーズユーザーの1月出金データ修正
-- ========================================
-- 59C23C: phase=HOLD, 紹介報酬出金不可
-- 177B83: NFT自動付与後phase=HOLD, 紹介報酬出金不可
-- ========================================

-- STEP 1: 修正前の状態
SELECT '=== STEP 1: 修正前の出金データ ===' as section;
SELECT 
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

-- STEP 2: 紹介報酬を0にして、total_amountを再計算
SELECT '=== STEP 2: 出金データ修正 ===' as section;
UPDATE monthly_withdrawals
SET 
  referral_amount = 0,
  total_amount = personal_amount,  -- 個人利益のみ
  updated_at = NOW()
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

-- STEP 3: 修正後の状態
SELECT '=== STEP 3: 修正後の出金データ ===' as section;
SELECT 
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

-- STEP 4: $10未満になったかチェック
SELECT '=== STEP 4: $10未満チェック ===' as section;
SELECT 
  user_id,
  total_amount,
  CASE WHEN total_amount < 10 THEN '⚠️ $10未満（出金対象外）' ELSE '✓ OK' END as status_check
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';
