-- ========================================
-- available_usdt修正（日利合計ベース）
-- ========================================
-- 修正日: 2026-02-06
--
-- 問題: completed出金のpersonal_amountが信用できない
-- 解決: pending出金がないユーザーは日利合計をそのまま使う
--
-- ロジック:
--   1. pending出金あり → personal_amount（既に修正済み）
--   2. pending出金なし → 日利合計（出金履歴は無視）
-- ========================================

-- STEP 0: 現状確認
SELECT '=== STEP 0: 修正対象の確認 ===' as section;
SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'pending') THEN 'pending出金あり'
    ELSE 'pending出金なし'
  END as category,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE ac.available_usdt < 0) as "マイナス数"
FROM affiliate_cycle ac
GROUP BY 1;

-- STEP 1: pending出金がないユーザーのavailable_usdtを日利合計で更新
SELECT '=== STEP 1: pending出金なしユーザーを日利合計で更新 ===' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = COALESCE(dp.total_profit, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp
WHERE ac.user_id = dp.user_id
  AND NOT EXISTS (
    SELECT 1 FROM monthly_withdrawals mw
    WHERE mw.user_id = ac.user_id AND mw.status = 'pending'
  );

-- STEP 2: 日利データがないユーザーは0
UPDATE affiliate_cycle ac
SET
  available_usdt = 0,
  updated_at = NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM nft_daily_profit ndp WHERE ndp.user_id = ac.user_id
)
AND NOT EXISTS (
  SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'pending'
);

-- STEP 3: 結果確認
SELECT '=== STEP 3: 修正後の統計 ===' as section;
SELECT
  COUNT(*) as "全ユーザー",
  COUNT(*) FILTER (WHERE available_usdt < -100) as "< -$100",
  COUNT(*) FILTER (WHERE available_usdt >= -100 AND available_usdt < 0) as "-$100〜$0",
  COUNT(*) FILTER (WHERE available_usdt >= 0 AND available_usdt < 10) as "$0〜$10",
  COUNT(*) FILTER (WHERE available_usdt >= 10) as "$10以上",
  ROUND(SUM(available_usdt)::numeric, 2) as "合計"
FROM affiliate_cycle;

-- STEP 4: サンプル確認
SELECT '=== STEP 4: 以前マイナスだったユーザーの確認 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(COALESCE(dp.total, 0)::numeric, 2) as "日利合計",
  ac.phase
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit GROUP BY user_id
) dp ON ac.user_id = dp.user_id
WHERE ac.user_id IN ('A54290', '0B2371', 'DD525A', '047E33', '93E0DC', '9DDF45', '96F528')
ORDER BY ac.user_id;

-- STEP 5: pending出金との整合性最終確認
SELECT '=== STEP 5: pending出金との整合性 ===' as section;
SELECT
  COUNT(*) as "pending出金ユーザー",
  COUNT(*) FILTER (WHERE ABS(ac.available_usdt - mw.personal_amount) < 0.01) as "一致",
  COUNT(*) FILTER (WHERE ABS(ac.available_usdt - mw.personal_amount) >= 0.01) as "不一致"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.status = 'pending';

SELECT '✅ available_usdt修正完了（日利合計ベース）' as status;
