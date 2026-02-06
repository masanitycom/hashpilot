-- ========================================
-- available_usdt修正（日利のみに限定）
-- ========================================
-- 修正日: 2026-02-06
--
-- 問題: available_usdtに紹介報酬が混在していた
-- 正しい設計:
--   available_usdt = 日利合計 - 出金済み個人利益
--   cum_usdt = 紹介報酬累計（NFTサイクル用）
--   withdrawn_referral_usdt = 出金済み紹介報酬
--   月末出金額 = available_usdt + (USDTフェーズならcum_usdt - withdrawn_referral_usdt)
-- ========================================

-- STEP 0: 修正前の確認
SELECT '=== STEP 0: 修正前の状態（サンプル） ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "現在available_usdt",
  ROUND(COALESCE(dp.total, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(w.personal, 0)::numeric, 2) as "出金済み個人",
  ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal, 0))::numeric, 2) as "正しいavailable_usdt",
  ROUND((ac.available_usdt - (COALESCE(dp.total, 0) - COALESCE(w.personal, 0)))::numeric, 2) as "差分"
FROM affiliate_cycle ac
LEFT JOIN (SELECT user_id, SUM(daily_profit) as total FROM nft_daily_profit GROUP BY user_id) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(COALESCE(personal_amount, total_amount)) as personal
  FROM monthly_withdrawals WHERE status = 'completed' GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ABS(ac.available_usdt - (COALESCE(dp.total, 0) - COALESCE(w.personal, 0))) > 1
ORDER BY ABS(ac.available_usdt - (COALESCE(dp.total, 0) - COALESCE(w.personal, 0))) DESC
LIMIT 20;

-- STEP 1: available_usdtを正しい値に一括更新
SELECT '=== STEP 1: available_usdtを一括修正 ===' as section;

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
  SELECT user_id, SUM(COALESCE(personal_amount, total_amount)) as personal
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON dp.user_id = w.user_id
WHERE ac.user_id = dp.user_id;

-- 日利がないユーザーも修正（出金があれば負の値に）
UPDATE affiliate_cycle ac
SET
  available_usdt = ROUND(-COALESCE(w.personal, 0)::numeric, 2),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(COALESCE(personal_amount, total_amount)) as personal
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w
WHERE ac.user_id = w.user_id
  AND NOT EXISTS (SELECT 1 FROM nft_daily_profit ndp WHERE ndp.user_id = ac.user_id);

-- STEP 2: 修正後の確認
SELECT '=== STEP 2: 修正後の確認 ===' as section;
SELECT
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE available_usdt < 0) as "マイナスユーザー数",
  COUNT(*) FILTER (WHERE available_usdt >= 0) as "プラスユーザー数",
  ROUND(SUM(available_usdt)::numeric, 2) as "合計",
  ROUND(MIN(available_usdt)::numeric, 2) as "最小",
  ROUND(MAX(available_usdt)::numeric, 2) as "最大"
FROM affiliate_cycle;

-- STEP 3: 自動NFTユーザーの確認
SELECT '=== STEP 3: 自動NFTユーザーの状態 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ac.phase,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ROUND((ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能紹介報酬",
  ROUND((ac.available_usdt + 
    CASE WHEN ac.phase = 'USDT' THEN GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0)) ELSE 0 END
  )::numeric, 2) as "合計出金可能額"
FROM affiliate_cycle ac
WHERE ac.auto_nft_count > 0
ORDER BY ac.user_id;

SELECT '✅ available_usdt修正完了（日利のみに限定）' as status;
