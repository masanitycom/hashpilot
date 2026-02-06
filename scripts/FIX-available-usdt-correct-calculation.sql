-- ========================================
-- available_usdt正しい再計算
-- ========================================
-- 修正日: 2026-02-06
--
-- 問題: 前回の修正で COALESCE(personal_amount, total_amount) を使用したため、
--       personal_amountがNULLの場合にtotal_amount（紹介報酬含む）が使われた
--
-- 正しい設計:
--   available_usdt = 日利合計（全期間） - 出金済み個人利益（全期間）
--   ※ 出金済み個人利益 = completed出金の personal_amount の合計
--   ※ personal_amountがNULLの場合は、total_amount - referral_amount で計算
-- ========================================

-- STEP 0: 現在の問題状態を確認
SELECT '=== STEP 0: 現在の問題状態 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "現在available_usdt",
  ROUND(COALESCE(dp.total, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(w.personal_correct, 0)::numeric, 2) as "出金済み個人(正)",
  ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal_correct, 0))::numeric, 2) as "正しいavailable_usdt"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  -- 正しい個人利益出金額の計算
  -- personal_amount が設定されていればそれを使用
  -- NULLの場合は total_amount - COALESCE(referral_amount, 0) で計算
  SELECT
    user_id,
    SUM(
      CASE
        WHEN personal_amount IS NOT NULL THEN personal_amount
        ELSE total_amount - COALESCE(referral_amount, 0)
      END
    ) as personal_correct
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ac.user_id IN ('177B83', '59C23C')
ORDER BY ac.user_id;

-- STEP 1: 出金履歴の詳細確認
SELECT '=== STEP 1: 出金履歴詳細（177B83, 59C23C）===' as section;
SELECT
  user_id,
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as "personal_amount",
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as "referral_amount",
  ROUND(total_amount::numeric, 2) as "total_amount",
  ROUND((total_amount - COALESCE(referral_amount, 0))::numeric, 2) as "計算した個人利益"
FROM monthly_withdrawals
WHERE user_id IN ('177B83', '59C23C')
ORDER BY user_id, withdrawal_month;

-- STEP 2: 日利の月別内訳確認
SELECT '=== STEP 2: 月別日利（177B83）===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit
FROM nft_daily_profit
WHERE user_id = '177B83'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

SELECT '=== STEP 2: 月別日利（59C23C）===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit
FROM nft_daily_profit
WHERE user_id = '59C23C'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- STEP 3: available_usdtを正しく再計算
SELECT '=== STEP 3: available_usdt再計算実行 ===' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal_correct, 0))::numeric, 2),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  GROUP BY user_id
) dp
LEFT JOIN (
  SELECT
    user_id,
    SUM(
      CASE
        WHEN personal_amount IS NOT NULL THEN personal_amount
        ELSE total_amount - COALESCE(referral_amount, 0)
      END
    ) as personal_correct
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON dp.user_id = w.user_id
WHERE ac.user_id = dp.user_id;

-- 日利がないユーザーで出金があるケース（0にリセット）
UPDATE affiliate_cycle ac
SET
  available_usdt = 0,
  updated_at = NOW()
WHERE NOT EXISTS (SELECT 1 FROM nft_daily_profit ndp WHERE ndp.user_id = ac.user_id)
  AND EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'completed');

-- 日利も出金もないユーザー（0にリセット）
UPDATE affiliate_cycle ac
SET
  available_usdt = 0,
  updated_at = NOW()
WHERE NOT EXISTS (SELECT 1 FROM nft_daily_profit ndp WHERE ndp.user_id = ac.user_id)
  AND NOT EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'completed');

-- STEP 4: 修正後の確認
SELECT '=== STEP 4: 修正後の状態（177B83, 59C23C）===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ac.phase,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能紹介報酬"
FROM affiliate_cycle ac
WHERE ac.user_id IN ('177B83', '59C23C')
ORDER BY ac.user_id;

-- STEP 5: 全体の統計
SELECT '=== STEP 5: 全体統計 ===' as section;
SELECT
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE available_usdt < 0) as "マイナスユーザー数",
  COUNT(*) FILTER (WHERE available_usdt >= 0) as "プラスユーザー数",
  ROUND(SUM(available_usdt)::numeric, 2) as "合計",
  ROUND(MIN(available_usdt)::numeric, 2) as "最小",
  ROUND(MAX(available_usdt)::numeric, 2) as "最大"
FROM affiliate_cycle;

-- STEP 6: pending出金との整合性確認
SELECT '=== STEP 6: pending出金との整合性 ===' as section;
SELECT
  mw.user_id,
  mw.withdrawal_month,
  ROUND(mw.personal_amount::numeric, 2) as "pending個人利益",
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  CASE
    WHEN ABS(COALESCE(mw.personal_amount, 0) - ac.available_usdt) < 1 THEN '✓ 一致'
    ELSE '⚠ 差分あり'
  END as status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.status = 'pending'
  AND mw.user_id IN ('177B83', '59C23C');

SELECT '✅ available_usdt再計算完了' as status;
