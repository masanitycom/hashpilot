-- ========================================
-- HOLDフェーズユーザーの払い出し可能額計算
-- ========================================
-- ロジック:
-- cum_usdt >= 1100 → HOLDフェーズ
-- 払い出し可能 = MIN(cum_usdt, 1100) - 既払い出し紹介報酬
-- ========================================

-- 1. HOLDフェーズユーザーの一覧
SELECT '=== 1. HOLDフェーズユーザー ===' as section;
SELECT
  ac.user_id,
  u.email,
  ac.cum_usdt,
  ac.available_usdt,
  ac.phase,
  COALESCE(ac.withdrawn_referral_usdt, 0) as withdrawn_referral,
  -- ロック額（$1,100固定、ただしcum_usdtが$1,100未満なら全額ロック）
  LEAST(ac.cum_usdt, 1100) as lock_amount,
  -- 払い出し可能な紹介報酬
  GREATEST(LEAST(ac.cum_usdt, 1100) - COALESCE(ac.withdrawn_referral_usdt, 0), 0) as withdrawable_referral
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.phase = 'HOLD'
  OR ac.cum_usdt >= 1100
ORDER BY ac.cum_usdt DESC;

-- 2. 177B83の詳細
SELECT '=== 2. 177B83 詳細 ===' as section;
SELECT
  ac.user_id,
  ac.cum_usdt,
  ac.available_usdt,
  ac.phase,
  COALESCE(ac.withdrawn_referral_usdt, 0) as withdrawn_referral,
  1100 as lock_amount,
  GREATEST(1100 - COALESCE(ac.withdrawn_referral_usdt, 0), 0) as withdrawable_referral_from_hold,
  ac.available_usdt as withdrawable_personal
FROM affiliate_cycle ac
WHERE ac.user_id = '177B83';

-- 3. 11月の紹介報酬払い出し確認
SELECT '=== 3. 11月の紹介報酬払い出し ===' as section;
SELECT
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 4. withdrawn_referral_usdtが設定されているか確認
SELECT '=== 4. withdrawn_referral_usdt確認 ===' as section;
SELECT
  user_id,
  cum_usdt,
  withdrawn_referral_usdt,
  phase
FROM affiliate_cycle
WHERE cum_usdt >= 1100
ORDER BY cum_usdt DESC
LIMIT 20;

-- 5. 11月完了済み出金から紹介報酬払い出し額を計算
SELECT '=== 5. 11月完了済みの紹介報酬払い出し ===' as section;
SELECT
  mw.user_id,
  mw.referral_amount as nov_referral_paid,
  ac.cum_usdt,
  ac.withdrawn_referral_usdt,
  CASE
    WHEN ac.withdrawn_referral_usdt IS NULL OR ac.withdrawn_referral_usdt = 0
    THEN '❌ withdrawn_referral_usdt未設定'
    ELSE '✓ 設定済み'
  END as status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
  AND mw.referral_amount > 0
ORDER BY mw.referral_amount DESC
LIMIT 20;
