-- ========================================
-- HOLDフェーズユーザーの出金合計を修正
-- ========================================
-- 問題: HOLDユーザーは払出可能な紹介報酬のみ出金可能なのに、
-- total_amount に全額が含まれている

-- ========================================
-- 修正前確認
-- ========================================
SELECT '=== 修正前: HOLDユーザーの出金合計 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount as stored_referral,
  ac.withdrawn_referral_usdt,
  mw.total_amount as current_total,
  -- 払出可能な紹介報酬 = max(0, 1100 - 既払い紹介報酬)
  GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0)) as withdrawable_referral,
  -- 正しい出金合計
  mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0)) as correct_total,
  -- 差額
  mw.total_amount - (mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))) as difference
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
ORDER BY mw.total_amount DESC;

-- ========================================
-- 修正実行
-- ========================================
SELECT '=== 修正実行 ===' as section;

-- HOLDユーザーの total_amount を修正
-- total_amount = personal_amount + 払出可能紹介報酬
UPDATE monthly_withdrawals mw
SET total_amount = mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD';

-- ========================================
-- 修正後確認
-- ========================================
SELECT '=== 修正後: HOLDユーザーの出金合計 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount as stored_referral,
  ac.withdrawn_referral_usdt,
  mw.total_amount as new_total,
  GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0)) as withdrawable_referral
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
ORDER BY mw.total_amount DESC;

-- ========================================
-- 全体統計（修正後）
-- ========================================
SELECT '=== 全体統計（修正後）===' as section;
SELECT
  COUNT(*) as total_users,
  SUM(personal_amount) as personal_total,
  SUM(total_amount) as withdrawal_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
