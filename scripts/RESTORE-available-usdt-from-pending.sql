-- ========================================
-- available_usdt復元（pending出金から）
-- ========================================
-- 修正日: 2026-02-06
--
-- ロジック:
--   pending出金のpersonal_amount = その月の日利 = 未出金額 = available_usdt
--   これを使って復元する
-- ========================================

-- STEP 0: 復元前の状態確認
SELECT '=== STEP 0: 復元前の状態（サンプル）===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "現在(壊れた)",
  ROUND(mw.personal_amount::numeric, 2) as "pending個人利益",
  ROUND((mw.personal_amount - ac.available_usdt)::numeric, 2) as "差分"
FROM affiliate_cycle ac
JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.status = 'pending'
ORDER BY ABS(mw.personal_amount - ac.available_usdt) DESC
LIMIT 10;

-- STEP 1: pending出金があるユーザーのavailable_usdtを復元
SELECT '=== STEP 1: pending出金ユーザーの復元 ===' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = mw.personal_amount,
  updated_at = NOW()
FROM monthly_withdrawals mw
WHERE ac.user_id = mw.user_id
  AND mw.status = 'pending'
  AND mw.personal_amount IS NOT NULL;

-- STEP 2: pending出金がないユーザーの処理
-- これらは:
--   - 日利がないユーザー → 0
--   - 出金対象外のユーザー → 日利合計 - 出金済み個人
SELECT '=== STEP 2: pending出金がないユーザーの確認 ===' as section;

-- 2-1: pending出金がなく、日利もないユーザー → 0
UPDATE affiliate_cycle ac
SET
  available_usdt = 0,
  updated_at = NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM monthly_withdrawals mw
  WHERE mw.user_id = ac.user_id AND mw.status = 'pending'
)
AND NOT EXISTS (
  SELECT 1 FROM nft_daily_profit ndp
  WHERE ndp.user_id = ac.user_id
);

-- 2-2: pending出金がなく、日利があるユーザー
-- → 日利合計 - 出金済み個人利益（completed分のみ）
UPDATE affiliate_cycle ac
SET
  available_usdt = ROUND((
    COALESCE(dp.total_profit, 0) - COALESCE(w.total_personal, 0)
  )::numeric, 2),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp
LEFT JOIN (
  SELECT
    user_id,
    SUM(
      CASE
        WHEN personal_amount IS NOT NULL THEN personal_amount
        ELSE GREATEST(0, total_amount - COALESCE(referral_amount, 0))
      END
    ) as total_personal
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON dp.user_id = w.user_id
WHERE ac.user_id = dp.user_id
  AND NOT EXISTS (
    SELECT 1 FROM monthly_withdrawals mw
    WHERE mw.user_id = ac.user_id AND mw.status = 'pending'
  );

-- STEP 3: 復元後の確認
SELECT '=== STEP 3: 復元後の状態 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(COALESCE(mw.personal_amount, 0)::numeric, 2) as "pending個人",
  ac.phase
FROM affiliate_cycle ac
LEFT JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.status = 'pending'
WHERE ac.user_id IN ('177B83', '59C23C', '9A3A16', 'A4C3C8', 'ACBFBA')
ORDER BY ac.user_id;

-- STEP 4: 全体統計
SELECT '=== STEP 4: 復元後の全体統計 ===' as section;
SELECT
  COUNT(*) as "全ユーザー",
  COUNT(*) FILTER (WHERE available_usdt < 0) as "マイナス",
  COUNT(*) FILTER (WHERE available_usdt >= 0 AND available_usdt < 10) as "$0-10",
  COUNT(*) FILTER (WHERE available_usdt >= 10) as "$10以上",
  ROUND(SUM(available_usdt)::numeric, 2) as "合計",
  ROUND(MIN(available_usdt)::numeric, 2) as "最小",
  ROUND(MAX(available_usdt)::numeric, 2) as "最大"
FROM affiliate_cycle;

-- STEP 5: pending出金との整合性最終確認
SELECT '=== STEP 5: pending出金との整合性 ===' as section;
SELECT
  COUNT(*) as "pending出金ユーザー",
  COUNT(*) FILTER (WHERE ABS(ac.available_usdt - mw.personal_amount) < 0.01) as "一致",
  COUNT(*) FILTER (WHERE ABS(ac.available_usdt - mw.personal_amount) >= 0.01) as "不一致"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.status = 'pending';

SELECT '✅ available_usdt復元完了' as status;
