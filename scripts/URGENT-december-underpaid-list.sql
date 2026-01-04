-- ========================================
-- 【緊急】12月出金で紹介報酬が未払いのユーザーリスト
-- ========================================
-- 問題: A81A5Eのように、紹介報酬がtotal_amountに含まれていない
-- 原因: 月末処理時にavailable_usdtに紹介報酬が加算されていなかった
-- ========================================

-- ========================================
-- 1. 追加支払いが必要なユーザー一覧
-- ========================================
SELECT '=== 追加支払いが必要なユーザー ===' as section;

SELECT
  mw.user_id,
  u.email,
  u.coinw_uid,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount as "11月紹介報酬",
  mw.total_amount as "支払済み",
  CASE
    WHEN ac.phase = 'USDT' THEN mw.referral_amount
    ELSE 0
  END as "追加支払い必要額",
  mw.status
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
  AND mw.total_amount < (mw.personal_amount + mw.referral_amount)
  AND ac.phase = 'USDT'  -- USDTフェーズのみ（紹介報酬出金可能）
ORDER BY mw.referral_amount DESC;

-- ========================================
-- 2. 合計金額
-- ========================================
SELECT '=== 未払い合計 ===' as section;

SELECT
  COUNT(*) as "対象ユーザー数",
  SUM(mw.referral_amount) as "未払い紹介報酬合計"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
  AND mw.total_amount < (mw.personal_amount + mw.referral_amount)
  AND ac.phase = 'USDT';

-- ========================================
-- 3. HOLDフェーズのユーザー（紹介報酬は保留中）
-- ========================================
SELECT '=== HOLDフェーズ（紹介報酬は保留中・NFT購入に回る） ===' as section;

SELECT
  mw.user_id,
  u.email,
  ac.phase,
  ac.cum_usdt,
  mw.referral_amount as "11月紹介報酬",
  'NFT自動購入待ち（出金不可）' as note
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
  AND mw.referral_amount > 0
ORDER BY ac.cum_usdt DESC;

-- ========================================
-- 4. 最終確認：A81A5Eの状態
-- ========================================
SELECT '=== A81A5E確認 ===' as section;

SELECT
  mw.user_id,
  u.email,
  u.coinw_uid,
  mw.personal_amount as "個人利益",
  mw.referral_amount as "11月紹介報酬",
  mw.total_amount as "支払済み",
  mw.referral_amount as "追加支払い額",
  ac.phase
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id = 'A81A5E'
  AND mw.withdrawal_month = '2025-12-01';
