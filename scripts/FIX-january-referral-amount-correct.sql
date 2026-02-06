-- ========================================
-- 1月referral_amountを正しい出金可能額に修正
-- ========================================

-- 1. まず先ほどの間違った修正を確認
SELECT '=== 1. 現状（間違った設定） ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ROUND(mw.referral_amount::numeric, 2) as "現在referral_amount",
  ROUND(mw.total_amount::numeric, 2) as "現在total"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('59C23C', '177B83', '5FAE2C', '380CE2');

-- 2. 正しい出金可能紹介報酬の計算
-- USDTフェーズ: cum_usdt - withdrawn_referral_usdt（ただし0以上）
-- HOLDフェーズ: cum_usdt - 1100 - withdrawn_referral_usdt（ただし0以上）
SELECT '=== 2. 正しい出金可能紹介報酬 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn",
  CASE
    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
  END as "正しい出金可能額"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('59C23C', '177B83', '5FAE2C', '380CE2');

-- 3. 全ユーザーのreferral_amountを正しく修正
UPDATE monthly_withdrawals mw
SET
  referral_amount = CASE
    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    ELSE 0
  END,
  total_amount = mw.personal_amount + CASE
    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    ELSE 0
  END
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold');

-- 4. 修正後の確認
SELECT '=== 4. 修正後の4名 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(mw.personal_amount::numeric, 2) as "個人利益",
  ROUND(mw.referral_amount::numeric, 2) as "紹介報酬",
  ROUND(mw.total_amount::numeric, 2) as "出金合計"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('59C23C', '177B83', '5FAE2C', '380CE2');

-- 5. 全体統計
SELECT '=== 5. 全体統計 ===' as section;
SELECT
  COUNT(*) as "総数",
  COUNT(*) FILTER (WHERE referral_amount > 0) as "referral>0",
  ROUND(SUM(referral_amount)::numeric, 2) as "紹介報酬合計",
  ROUND(SUM(total_amount)::numeric, 2) as "出金合計"
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND status IN ('pending', 'on_hold');
