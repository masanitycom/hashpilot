-- ========================================
-- available_usdt復元スクリプト
-- ========================================
-- 修正日: 2026-02-06
--
-- 正しい計算式:
--   available_usdt = 日利合計（全期間） - 出金済み個人利益（completed分）
--
-- personal_amountの取得方法:
--   1. personal_amount が設定されていればそれを使用
--   2. personal_amount が NULL なら total_amount - COALESCE(referral_amount, 0)
--      ※ total_amount = personal + referral の関係があるため
-- ========================================

-- STEP 0: バックアップ用に現在の状態を記録
SELECT '=== STEP 0: 現在の状態（バックアップ用）===' as section;
SELECT
  user_id,
  ROUND(available_usdt::numeric, 2) as available_usdt_before,
  ROUND(cum_usdt::numeric, 2) as cum_usdt,
  phase
FROM affiliate_cycle
WHERE user_id IN ('177B83', '59C23C')
ORDER BY user_id;

-- STEP 1: 出金履歴の確認（personal_amountの状態）
SELECT '=== STEP 1: 出金履歴の個人利益確認 ===' as section;
SELECT
  user_id,
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as personal_amount,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral_amount,
  ROUND(total_amount::numeric, 2) as total_amount,
  CASE
    WHEN personal_amount IS NOT NULL THEN personal_amount
    ELSE total_amount - COALESCE(referral_amount, 0)
  END as "計算した個人利益"
FROM monthly_withdrawals
WHERE user_id IN ('177B83', '59C23C')
ORDER BY user_id, withdrawal_month;

-- STEP 2: 正しいavailable_usdtの計算確認
SELECT '=== STEP 2: 正しいavailable_usdt計算 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "現在(壊れた)",
  ROUND(COALESCE(dp.total, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(w.personal, 0)::numeric, 2) as "出金済み個人",
  ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal, 0))::numeric, 2) as "正しい値"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT
    user_id,
    SUM(
      CASE
        WHEN personal_amount IS NOT NULL THEN personal_amount
        ELSE total_amount - COALESCE(referral_amount, 0)
      END
    ) as personal
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ac.user_id IN ('177B83', '59C23C')
ORDER BY ac.user_id;

-- STEP 3: 全ユーザーのavailable_usdtを復元
SELECT '=== STEP 3: available_usdt復元実行 ===' as section;

-- 3-1: 日利と出金両方あるユーザー
UPDATE affiliate_cycle ac
SET
  available_usdt = ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal, 0))::numeric, 2),
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
    ) as personal
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON dp.user_id = w.user_id
WHERE ac.user_id = dp.user_id;

-- 3-2: 日利がないユーザー（available_usdt = 0）
UPDATE affiliate_cycle ac
SET
  available_usdt = 0,
  updated_at = NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM nft_daily_profit ndp WHERE ndp.user_id = ac.user_id
);

-- STEP 4: 復元後の確認
SELECT '=== STEP 4: 復元後の状態 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ac.phase,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能紹介"
FROM affiliate_cycle ac
WHERE ac.user_id IN ('177B83', '59C23C')
ORDER BY ac.user_id;

-- STEP 5: pending出金との整合性確認
SELECT '=== STEP 5: pending出金との整合性 ===' as section;
SELECT
  mw.user_id,
  mw.withdrawal_month,
  ROUND(COALESCE(mw.personal_amount, 0)::numeric, 2) as "pending個人利益",
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND((ac.available_usdt - COALESCE(mw.personal_amount, 0))::numeric, 2) as "差分"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.status = 'pending'
  AND mw.user_id IN ('177B83', '59C23C');

-- STEP 6: 全体統計
SELECT '=== STEP 6: 全体統計 ===' as section;
SELECT
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE available_usdt < 0) as "マイナス",
  COUNT(*) FILTER (WHERE available_usdt >= 0 AND available_usdt < 10) as "0-10未満",
  COUNT(*) FILTER (WHERE available_usdt >= 10) as "10以上",
  ROUND(SUM(available_usdt)::numeric, 2) as "合計",
  ROUND(MIN(available_usdt)::numeric, 2) as "最小",
  ROUND(MAX(available_usdt)::numeric, 2) as "最大"
FROM affiliate_cycle;

SELECT '✅ available_usdt復元完了' as status;
