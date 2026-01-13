-- ========================================
-- monthly_withdrawals HOLDユーザーデータ修正
-- 実行日: 2026-01-13
-- ========================================
-- 問題: HOLDフェーズのユーザーにreferral_amountが設定されている
-- 仕様: HOLDフェーズ → 紹介報酬出金不可（次のNFT付与待ち）
-- ========================================

-- ========================================
-- STEP 1: 現状のデータ確認（問題のあるレコード）
-- ========================================
SELECT '=== STEP 1: HOLDユーザーで紹介報酬が設定されているレコード ===' as section;

SELECT
  mw.user_id,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
  mw.status,
  ac.phase as current_phase,
  ac.cum_usdt,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  CASE
    WHEN mw.status = 'completed' THEN '⚠️ 完了済み'
    WHEN mw.status IN ('pending', 'on_hold') THEN '🔧 修正可能'
    ELSE '❓ 不明'
  END as action_status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
ORDER BY mw.withdrawal_month DESC, mw.referral_amount DESC;

-- ========================================
-- STEP 2: データ整合性問題の確認（total ≠ personal + referral）
-- ========================================
SELECT '=== STEP 2: データ整合性問題（total ≠ personal + referral） ===' as section;

SELECT
  mw.user_id,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
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
-- STEP 3: 修正対象の詳細（pending/on_hold のみ修正）
-- ========================================
SELECT '=== STEP 3: 修正対象詳細 ===' as section;

SELECT
  mw.id,
  mw.user_id,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
  mw.status,
  ac.phase,
  '修正前' as state,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
  AND mw.status IN ('pending', 'on_hold')

UNION ALL

SELECT
  mw.id,
  mw.user_id,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
  mw.status,
  ac.phase,
  '修正後' as state,
  mw.personal_amount,
  0 as referral_amount,
  mw.personal_amount as total_amount
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
  AND mw.status IN ('pending', 'on_hold')

ORDER BY user_id, month, state;

-- ========================================
-- STEP 4: 修正実行（未完了のHOLDユーザーのみ）
-- ========================================
SELECT '=== STEP 4: 修正実行 ===' as section;

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
-- STEP 5: 修正後の確認
-- ========================================
SELECT '=== STEP 5: 修正後の確認 ===' as section;

SELECT
  mw.user_id,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
  mw.status,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  CASE
    WHEN ac.phase = 'HOLD' AND mw.referral_amount = 0 THEN '✅ 修正済み'
    WHEN ac.phase = 'USDT' THEN '✅ 正常'
    WHEN mw.status = 'completed' THEN '⚠️ 完了済み（未修正）'
    ELSE '❓ 確認必要'
  END as check_result
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id IN ('59C23C', '177B83')
ORDER BY mw.user_id, mw.withdrawal_month DESC;

-- ========================================
-- STEP 6: 全体統計（フェーズ別・月別）
-- ========================================
SELECT '=== STEP 6: 全体統計（フェーズ別・月別） ===' as section;

SELECT
  ac.phase,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
  COUNT(*) as records,
  SUM(mw.personal_amount) as total_personal,
  SUM(mw.referral_amount) as total_referral,
  SUM(mw.total_amount) as total_amount
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
GROUP BY ac.phase, mw.withdrawal_month
ORDER BY mw.withdrawal_month DESC, ac.phase;

-- ========================================
-- 完了メッセージ
-- ========================================
SELECT '✅ HOLDユーザーのreferral_amount修正完了' as status;
SELECT 'HOLDフェーズのpending/on_hold出金のreferral_amountを0に設定しました' as detail1;
SELECT '完了済み（completed）の出金は変更していません（既に送金済みのため）' as detail2;
