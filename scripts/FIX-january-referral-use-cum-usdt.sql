-- ========================================
-- 1月referral_amount = cum_usdt（出金可能残高）
-- ========================================

-- 1. 修正前確認
SELECT '=== 1. 修正前 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt(出金可能)",
  ROUND(mw.referral_amount::numeric, 2) as "現在referral",
  ROUND(mw.total_amount::numeric, 2) as "現在total"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('59C23C', '177B83', '5FAE2C', '380CE2');

-- 2. 全ユーザーのreferral_amountをcum_usdtで更新
-- USDTフェーズ: cum_usdt全額
-- HOLDフェーズ: cum_usdt - 1100（ロック分）
UPDATE monthly_withdrawals mw
SET
  referral_amount = CASE
    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt)::numeric, 2)
    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100)::numeric, 2)
    ELSE 0
  END,
  total_amount = mw.personal_amount + CASE
    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt)::numeric, 2)
    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100)::numeric, 2)
    ELSE 0
  END
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold');

-- 3. 修正後確認
SELECT '=== 3. 修正後 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(mw.personal_amount::numeric, 2) as "個人利益",
  ROUND(mw.referral_amount::numeric, 2) as "紹介報酬",
  ROUND(mw.total_amount::numeric, 2) as "出金合計"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('59C23C', '177B83', '5FAE2C', '380CE2');

-- 4. 全体統計
SELECT '=== 4. 全体統計 ===' as section;
SELECT
  COUNT(*) as "総数",
  COUNT(*) FILTER (WHERE referral_amount > 0) as "referral>0",
  ROUND(SUM(referral_amount)::numeric, 2) as "紹介報酬合計",
  ROUND(SUM(total_amount)::numeric, 2) as "出金合計"
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND status IN ('pending', 'on_hold');
