-- ========================================
-- 月末出金データの確認と修正
-- 実行日: 2026-01-13
-- ========================================
-- 問題: HOLDユーザーでもreferral_amountが設定されている
-- 仕様: HOLDフェーズは紹介報酬出金不可（次のNFT付与待ち）
-- ========================================

-- ========================================
-- STEP 1: 全出金データの現状確認
-- ========================================
SELECT '=== STEP 1: 全出金データの現状確認 ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.status,
  ac.phase as current_phase,
  ac.cum_usdt,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  CASE
    WHEN mw.personal_amount + mw.referral_amount = mw.total_amount THEN '✅'
    ELSE '❌ 不整合'
  END as integrity_check
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
ORDER BY mw.withdrawal_month DESC, mw.user_id;

-- ========================================
-- STEP 2: データ整合性の問題を特定
-- ========================================
SELECT '=== STEP 2: データ整合性の問題（total ≠ personal + referral） ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.status,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  (mw.personal_amount + mw.referral_amount) as expected_total,
  mw.total_amount - (mw.personal_amount + mw.referral_amount) as difference
FROM monthly_withdrawals mw
WHERE ABS(mw.total_amount - (mw.personal_amount + mw.referral_amount)) > 0.01
ORDER BY mw.withdrawal_month DESC;

-- ========================================
-- STEP 3: HOLDユーザーで紹介報酬がある問題
-- ========================================
SELECT '=== STEP 3: HOLDユーザーで紹介報酬があるレコード ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.status,
  ac.phase as current_phase,
  ac.cum_usdt,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  CASE
    WHEN mw.status = 'completed' THEN '⚠️ 完了済み（変更不可）'
    ELSE '🔧 修正可能'
  END as action
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
ORDER BY mw.withdrawal_month DESC, mw.referral_amount DESC;

-- ========================================
-- STEP 4: 未完了のHOLD出金のみ修正（完了済みは触らない）
-- ========================================
SELECT '=== STEP 4: 未完了HOLDユーザーの修正 ===' as section;

-- 修正前の確認
SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.status,
  ac.phase,
  mw.referral_amount as '修正前referral',
  mw.total_amount as '修正前total',
  0 as '修正後referral',
  mw.personal_amount as '修正後total'
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
  AND mw.status IN ('pending', 'on_hold');

-- 修正実行（未完了のHOLDユーザーのみ）
UPDATE monthly_withdrawals mw
SET
  referral_amount = 0,
  total_amount = personal_amount,
  updated_at = NOW()
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND ac.phase = 'HOLD'
  AND mw.referral_amount > 0
  AND mw.status IN ('pending', 'on_hold');

-- ========================================
-- STEP 5: 59C23Cと177B83の確認
-- ========================================
SELECT '=== STEP 5: 特定ユーザーの確認（59C23C, 177B83） ===' as section;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.status,
  ac.phase,
  ac.cum_usdt,
  ac.auto_nft_count,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id IN ('59C23C', '177B83')
ORDER BY mw.user_id, mw.withdrawal_month;

-- ========================================
-- STEP 6: 177B83のデータ整合性問題を修正
-- ========================================
SELECT '=== STEP 6: 177B83のデータ整合性確認 ===' as section;

-- 177B83の問題：referral_amount: $814.607 だが total_amount: $23.408
-- これはtotal_amountが間違っている可能性
SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  ac.phase,
  CASE
    WHEN ac.phase = 'HOLD' THEN mw.personal_amount
    ELSE mw.personal_amount + mw.referral_amount
  END as correct_total
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id = '177B83';

-- ========================================
-- STEP 7: 完了済み出金の注記
-- ========================================
SELECT '=== STEP 7: 完了済み出金の問題（参考情報） ===' as section;
SELECT '⚠️ 完了済みの出金は既に送金済みのため、データベースの値は変更しません' as note;
SELECT '⚠️ 実際の送金額と表示が異なる場合があります' as note2;

SELECT
  mw.user_id,
  mw.withdrawal_month,
  ac.phase as current_phase,
  mw.referral_amount as 'データ上の紹介報酬',
  CASE
    WHEN ac.phase = 'HOLD' THEN '実際は送金されていない可能性'
    ELSE '正常に送金済み'
  END as note
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
  AND mw.status = 'completed';

SELECT '✅ 確認・修正完了' as status;
