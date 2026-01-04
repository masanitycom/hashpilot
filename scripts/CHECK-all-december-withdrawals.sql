-- ========================================
-- 12月出金の全体確認
-- ========================================

-- 1. フェーズ別の出金状況
SELECT '=== フェーズ別出金状況 ===' as section;
SELECT
  ac.phase,
  COUNT(*) as user_count,
  SUM(mw.personal_amount) as personal_total,
  SUM(mw.referral_amount) as referral_stored,
  SUM(mw.total_amount) as total_amount
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
GROUP BY ac.phase
ORDER BY ac.phase;

-- 2. USDTユーザーの確認（正しいはず）
SELECT '=== USDTユーザー: total_amount検証 ===' as section;
SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  mw.personal_amount + COALESCE(mw.referral_amount, 0) as expected_total,
  mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0)) as difference
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'USDT'
  AND ABS(mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0))) > 0.01
ORDER BY ABS(mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0))) DESC
LIMIT 20;

-- 3. HOLDユーザーの確認（修正が必要）
SELECT '=== HOLDユーザー: total_amount検証 ===' as section;
SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount as stored_referral,
  ac.withdrawn_referral_usdt,
  GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0)) as withdrawable_referral,
  mw.total_amount as current_total,
  mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0)) as expected_total,
  mw.total_amount - (mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))) as difference
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
ORDER BY mw.total_amount DESC;

-- 4. 差額が大きいユーザー一覧（全フェーズ）
SELECT '=== 差額が大きいユーザー（全フェーズ）===' as section;
SELECT
  mw.user_id,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  CASE
    WHEN ac.phase = 'HOLD' THEN
      mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))
    ELSE
      mw.personal_amount + COALESCE(mw.referral_amount, 0)
  END as expected_total,
  mw.total_amount - CASE
    WHEN ac.phase = 'HOLD' THEN
      mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))
    ELSE
      mw.personal_amount + COALESCE(mw.referral_amount, 0)
  END as difference
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
HAVING ABS(mw.total_amount - CASE
    WHEN ac.phase = 'HOLD' THEN
      mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))
    ELSE
      mw.personal_amount + COALESCE(mw.referral_amount, 0)
  END) > 1
ORDER BY ABS(mw.total_amount - CASE
    WHEN ac.phase = 'HOLD' THEN
      mw.personal_amount + GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))
    ELSE
      mw.personal_amount + COALESCE(mw.referral_amount, 0)
  END) DESC;
