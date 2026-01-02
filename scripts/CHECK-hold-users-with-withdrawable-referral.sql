-- ========================================
-- HOLDフェーズユーザーの払い出し可能額一覧
-- ========================================
-- 177B83のケース:
-- - cum_usdt = $1,879.69（紹介報酬累計）
-- - phase = HOLD（$1,100がロック中）
-- - withdrawn_referral_usdt = $1,066.29（11月に払い出し済み）
-- - 今回払い出し可能 = $1,100 - $1,066.29 = $33.71
-- ========================================

-- 1. HOLDフェーズで払い出し可能額があるユーザー一覧
SELECT '=== 1. HOLDフェーズ: 払い出し可能額があるユーザー ===' as section;
SELECT
  ac.user_id,
  u.email,
  ac.cum_usdt,
  ac.phase,
  1100.00 as lock_amount,
  COALESCE(ac.withdrawn_referral_usdt, 0) as already_withdrawn,
  GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) as withdrawable_referral,
  ac.available_usdt as personal_profit_available,
  -- 今回の出金可能合計
  ac.available_usdt + GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) as total_withdrawable
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.phase = 'HOLD'
  AND ac.cum_usdt >= 1100
  AND GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) > 0
ORDER BY GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) DESC;

-- 2. HOLDフェーズで払い出し可能額がゼロのユーザー（既に$1,100全額払い出し済み）
SELECT '=== 2. HOLDフェーズ: 既に$1,100全額払い出し済み ===' as section;
SELECT
  ac.user_id,
  u.email,
  ac.cum_usdt,
  ac.phase,
  COALESCE(ac.withdrawn_referral_usdt, 0) as already_withdrawn
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.phase = 'HOLD'
  AND ac.cum_usdt >= 1100
  AND COALESCE(ac.withdrawn_referral_usdt, 0) >= 1100
ORDER BY ac.cum_usdt DESC;

-- 3. 177B83の詳細確認
SELECT '=== 3. 177B83の詳細 ===' as section;
SELECT
  ac.user_id,
  u.email,
  ac.cum_usdt as "紹介報酬累計",
  ac.phase as "フェーズ",
  1100.00 as "ロック額",
  COALESCE(ac.withdrawn_referral_usdt, 0) as "既払い出し",
  GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) as "今回払い出し可能"
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id = '177B83';

-- 4. 全HOLDユーザーの統計
SELECT '=== 4. HOLDユーザー統計 ===' as section;
SELECT
  COUNT(*) as total_hold_users,
  SUM(CASE WHEN GREATEST(1100 - COALESCE(withdrawn_referral_usdt, 0), 0) > 0 THEN 1 ELSE 0 END) as users_with_withdrawable,
  SUM(GREATEST(1100 - COALESCE(withdrawn_referral_usdt, 0), 0)) as total_withdrawable_amount
FROM affiliate_cycle
WHERE phase = 'HOLD' AND cum_usdt >= 1100;

-- 5. 12月分の出金レコードでHOLDユーザーを確認
SELECT '=== 5. 12月出金レコードのHOLDユーザー ===' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  ac.phase,
  ac.cum_usdt,
  COALESCE(ac.withdrawn_referral_usdt, 0) as already_withdrawn,
  GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) as still_withdrawable_from_hold,
  mw.status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
ORDER BY mw.total_amount DESC;
