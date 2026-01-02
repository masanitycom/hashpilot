-- ========================================
-- 12月出金の紹介報酬問題を調査
-- ========================================
-- 問題: cum_usdt >= 1100 のユーザー（HOLDフェーズ）は
--       紹介報酬を出金できないはずだが、出金レコードに含まれている可能性
-- ========================================

-- ========================================
-- 1. フェーズ別の出金状況
-- ========================================
SELECT '=== 1. フェーズ別出金状況 ===' as section;
SELECT
  ac.phase,
  COUNT(*) as user_count,
  SUM(mw.total_amount) as total_withdrawal,
  SUM(mw.personal_amount) as total_personal,
  SUM(mw.referral_amount) as total_referral,
  AVG(ac.cum_usdt) as avg_cum_usdt
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
GROUP BY ac.phase
ORDER BY ac.phase;

-- ========================================
-- 2. HOLDフェーズで紹介報酬が含まれているユーザー
-- ========================================
SELECT '=== 2. HOLDフェーズで紹介報酬が含まれているユーザー ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.cum_usdt,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
  AND COALESCE(mw.referral_amount, 0) > 0
ORDER BY mw.referral_amount DESC;

-- ========================================
-- 3. 問題のあるケース: cum_usdt >= 1100 なのに referral_amount > 0
-- ========================================
SELECT '=== 3. 問題のあるケース ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.cum_usdt,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  -- 正しい出金可能額
  mw.personal_amount as correct_withdrawal
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.cum_usdt >= 1100  -- HOLDフェーズ相当
  AND COALESCE(mw.referral_amount, 0) > 0
ORDER BY mw.referral_amount DESC
LIMIT 20;

-- ========================================
-- 4. available_usdtの内訳確認
-- available_usdt = 個人利益累積 + 出金可能な紹介報酬
-- ========================================
SELECT '=== 4. available_usdt内訳確認 ===' as section;
SELECT
  ac.user_id,
  ac.available_usdt,
  ac.cum_usdt,
  ac.phase,
  COALESCE(personal.total_personal, 0) as dec_personal,
  COALESCE(referral.total_referral, 0) as dec_referral,
  mw.total_amount as withdrawal_total,
  mw.personal_amount,
  mw.referral_amount
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_personal
  FROM nft_daily_profit
  WHERE date >= '2025-12-01' AND date < '2026-01-01'
  GROUP BY user_id
) personal ON ac.user_id = personal.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit_monthly
  WHERE year = 2025 AND month = 12
  GROUP BY user_id
) referral ON ac.user_id = referral.user_id
LEFT JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.withdrawal_month = '2025-12-01'
WHERE mw.id IS NOT NULL
ORDER BY ac.cum_usdt DESC
LIMIT 20;

-- ========================================
-- 5. 月末出金のavailable_usdtとpersonal+referralの関係
-- ========================================
SELECT '=== 5. available_usdt構成要素 ===' as section;

-- available_usdtは累積であり、12月だけの値ではない
-- しかしtotal_amountはavailable_usdt全額を設定している
-- personal_amountは12月だけの日利
-- referral_amountは12月だけの紹介報酬
-- → personal_amount + referral_amount != total_amount になる

SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  (mw.personal_amount + COALESCE(mw.referral_amount, 0)) as dec_total,
  mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0)) as difference,
  ac.available_usdt as current_available,
  ac.cum_usdt,
  ac.phase
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ABS(mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0))) > 1
ORDER BY ABS(mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0))) DESC
LIMIT 20;
