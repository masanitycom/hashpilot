-- ========================================
-- available_usdtの問題調査
-- ========================================

-- STEP 1: マイナスのユーザー数と内訳
SELECT '=== マイナスavailable_usdtの統計 ===' as section;
SELECT 
  COUNT(*) FILTER (WHERE available_usdt < 0) as "マイナスユーザー数",
  COUNT(*) FILTER (WHERE available_usdt >= 0) as "プラスユーザー数",
  COUNT(*) as "総ユーザー数",
  ROUND(SUM(CASE WHEN available_usdt < 0 THEN available_usdt ELSE 0 END)::numeric, 2) as "マイナス合計",
  MIN(available_usdt) as "最小値",
  MAX(available_usdt) as "最大値"
FROM affiliate_cycle;

-- STEP 2: 運用開始日別でマイナスのユーザー
SELECT '=== 運用開始日別マイナスユーザー ===' as section;
SELECT
  u.operation_start_date,
  COUNT(*) as user_count,
  ROUND(SUM(ac.available_usdt)::numeric, 2) as total_available_usdt,
  ROUND(AVG(ac.available_usdt)::numeric, 2) as avg_available_usdt
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.available_usdt < 0
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;

-- STEP 3: available_usdtの理論値計算
-- 理論値 = 日利合計 - 出金済み個人利益
SELECT '=== available_usdtの理論値との差（サンプル10件） ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ROUND(ac.available_usdt::numeric, 2) as "現在available_usdt",
  ROUND(COALESCE(dp.total_profit, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(w.personal_total, 0)::numeric, 2) as "出金済み個人利益",
  ROUND((COALESCE(dp.total_profit, 0) - COALESCE(w.personal_total, 0))::numeric, 2) as "理論値",
  ROUND((ac.available_usdt - (COALESCE(dp.total_profit, 0) - COALESCE(w.personal_total, 0)))::numeric, 2) as "差分"
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(COALESCE(personal_amount, total_amount)) as personal_total
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ac.available_usdt < 0
ORDER BY ac.available_usdt ASC
LIMIT 10;

-- STEP 4: 177B83と59C23Cの確認
SELECT '=== 自動NFTユーザー（177B83, 59C23C）の状態 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ac.phase,
  ac.auto_nft_count,
  ROUND(COALESCE(dp.total_profit, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(rp.total_referral, 0)::numeric, 2) as "紹介報酬合計"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ac.user_id IN ('177B83', '59C23C');
