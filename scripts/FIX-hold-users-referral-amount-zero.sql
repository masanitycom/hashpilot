-- ========================================
-- HOLDユーザーのreferral_amountを0に修正
-- 実行日: 2026-01-13
-- ========================================
-- 問題: HOLDユーザーでもreferral_amountが設定されている
-- 仕様: HOLDフェーズは紹介報酬出金不可（次のNFT付与待ち）
-- ========================================

-- ========================================
-- STEP 1: 現状確認
-- ========================================
SELECT '=== STEP 1: HOLDユーザーで紹介報酬が設定されているレコード ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  mw.status,
  CASE
    WHEN ac.phase = 'HOLD' AND mw.referral_amount > 0 THEN '❌ 要修正'
    WHEN ac.phase = 'USDT' THEN '✅ 正常'
    ELSE '⚠️ 確認必要'
  END as check_result
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.referral_amount > 0
ORDER BY mw.withdrawal_month DESC, mw.referral_amount DESC;

-- ========================================
-- STEP 2: 修正対象の確認
-- ========================================
SELECT '=== STEP 2: 修正対象（HOLDユーザーで紹介報酬がある） ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  ac.phase,
  ac.cum_usdt,
  mw.personal_amount as '個人利益(変更なし)',
  mw.referral_amount as '紹介報酬(0に変更)',
  mw.total_amount as '出金合計(修正後)',
  mw.personal_amount as '修正後出金合計'
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
ORDER BY mw.withdrawal_month DESC, mw.referral_amount DESC;

-- ========================================
-- STEP 3: 修正実行
-- ========================================
SELECT '=== STEP 3: HOLDユーザーのreferral_amountを0に修正 ===' as section;

-- HOLDユーザーのreferral_amountを0に、total_amountをpersonal_amountに修正
UPDATE monthly_withdrawals mw
SET
  referral_amount = 0,
  total_amount = personal_amount,
  updated_at = NOW()
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND ac.phase = 'HOLD'
  AND mw.referral_amount > 0;

SELECT '修正件数: ' || COUNT(*) as result
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount = 0
  AND mw.total_amount = mw.personal_amount;

-- ========================================
-- STEP 4: 修正後確認
-- ========================================
SELECT '=== STEP 4: 修正後の確認 ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  mw.status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id IN ('59C23C', '177B83')
ORDER BY mw.withdrawal_month DESC;

-- ========================================
-- STEP 5: 全体統計
-- ========================================
SELECT '=== STEP 5: 全体統計（フェーズ別） ===' as section;

SELECT
  ac.phase,
  mw.withdrawal_month,
  COUNT(*) as records,
  SUM(mw.personal_amount) as total_personal,
  SUM(mw.referral_amount) as total_referral,
  SUM(mw.total_amount) as total_amount
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
GROUP BY ac.phase, mw.withdrawal_month
ORDER BY mw.withdrawal_month DESC, ac.phase;

SELECT '✅ HOLDユーザーのreferral_amount修正完了' as status;
