-- ========================================
-- 12月出金で紹介報酬が支払われていないユーザーを抽出
-- ========================================
-- 問題: total_amount（出金額）にreferral_amount（紹介報酬）が含まれていない
-- 原因: 月末処理時にavailable_usdtに紹介報酬が加算されていなかった
-- ========================================

-- ========================================
-- 1. 紹介報酬が支払われていないユーザー一覧
-- 条件: 11月紹介報酬がある AND USDTフェーズ AND total_amount < personal + referral
-- ========================================
SELECT '=== 紹介報酬が未払いのユーザー一覧 ===' as section;

SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount as nov_referral,
  mw.total_amount as paid_amount,
  (mw.personal_amount + mw.referral_amount) as should_have_paid,
  (mw.personal_amount + mw.referral_amount) - mw.total_amount as underpaid_amount,
  ac.phase,
  mw.status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
  AND mw.total_amount < (mw.personal_amount + mw.referral_amount)
  AND ac.phase = 'USDT'  -- USDTフェーズのみ（紹介報酬出金可能）
ORDER BY (mw.personal_amount + mw.referral_amount) - mw.total_amount DESC;

-- ========================================
-- 2. 未払い合計
-- ========================================
SELECT '=== 未払い合計 ===' as section;

SELECT
  COUNT(*) as affected_users,
  SUM(mw.referral_amount) as total_referral,
  SUM(mw.total_amount) as total_paid,
  SUM((mw.personal_amount + mw.referral_amount) - mw.total_amount) as total_underpaid
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
  AND mw.total_amount < (mw.personal_amount + mw.referral_amount)
  AND ac.phase = 'USDT';

-- ========================================
-- 3. A81A5Eの詳細確認
-- ========================================
SELECT '=== A81A5E詳細 ===' as section;

SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount as paid,
  mw.personal_amount + mw.referral_amount as should_pay,
  mw.referral_amount as underpaid,
  ac.phase,
  ac.cum_usdt,
  ac.available_usdt
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id = 'A81A5E'
  AND mw.withdrawal_month = '2025-12-01';

-- ========================================
-- 4. 支払い不足額の詳細リスト（追加支払いが必要なユーザー）
-- ========================================
SELECT '=== 追加支払いが必要なユーザーリスト ===' as section;

SELECT
  mw.user_id,
  u.email,
  u.coinw_uid,
  mw.referral_amount as unpaid_referral,
  mw.status
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
  AND mw.total_amount < (mw.personal_amount + mw.referral_amount)
  AND ac.phase = 'USDT'
ORDER BY mw.referral_amount DESC;

-- ========================================
-- 5. HOLDフェーズのユーザー（紹介報酬は出金不可だが確認用）
-- ========================================
SELECT '=== HOLDフェーズのユーザー（参考） ===' as section;

SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  ac.phase,
  ac.cum_usdt,
  'HOLDなので紹介報酬は出金不可' as note
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
  AND mw.referral_amount > 0
ORDER BY mw.referral_amount DESC;
