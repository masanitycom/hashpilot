-- ========================================
-- available_usdt過剰の真の原因調査
-- ========================================
-- 11月誤配布は2名のみ。他の原因を探る
-- ========================================

-- 1. 過剰額があった（修正前）ユーザーの詳細分析
-- 修正後のデータから逆算して、何が加算されていたか調べる
SELECT '=== 1. 修正前の過剰額パターン分析 ===' as section;

-- 2. 12/15開始ユーザーの詳細（operation_start_date別）
SELECT '=== 2. 運用開始日別の傾向 ===' as section;
SELECT
  u.operation_start_date,
  COUNT(*) as user_count,
  SUM(ac.available_usdt) as total_available,
  SUM(COALESCE(dp.total, 0)) as total_daily_profit,
  SUM(COALESCE(rp.total, 0)) as total_referral
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM user_referral_profit_monthly
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE u.operation_start_date >= '2025-12-01'
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;

-- 3. 典型的な過剰額のパターン確認
-- 1NFT = $1000 → 1日の日利はだいたい$1-2程度
-- 過剰額が$23.912のユーザーが多数いた → これは何日分？
SELECT '=== 3. $23.912の過剰額パターン ===' as section;
SELECT
  23.912 / 1.952 as approx_days,
  '約12日分の日利に相当' as note;

-- 4. 12月1日運用開始で1NFTユーザーの日利合計確認
SELECT '=== 4. 1NFT保有・12/1開始ユーザーの日利 ===' as section;
SELECT
  ndp.user_id,
  u.operation_start_date,
  nm.nft_count,
  SUM(ndp.daily_profit) as total_profit,
  COUNT(DISTINCT ndp.date) as days_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) as nft_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm ON ndp.user_id = nm.user_id
WHERE u.operation_start_date = '2025-12-01'
  AND nm.nft_count = 1
GROUP BY ndp.user_id, u.operation_start_date, nm.nft_count
ORDER BY SUM(ndp.daily_profit) DESC
LIMIT 10;

-- 5. daily_yield_log_v2のprofit_per_nft確認
SELECT '=== 5. 12月の日利設定履歴（profit_per_nft） ===' as section;
SELECT
  date,
  profit_per_nft,
  daily_pnl
FROM daily_yield_log_v2
WHERE date >= '2025-12-01'
ORDER BY date
LIMIT 31;

-- 6. affiliate_cycleのcreated_at/updated_at確認
SELECT '=== 6. 12月開始ユーザーのaffiliate_cycle作成日 ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ac.available_usdt,
  ac.created_at,
  ac.updated_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.operation_start_date >= '2025-12-01'
ORDER BY ac.created_at
LIMIT 20;

-- 7. process_daily_yield_v2の処理ログ（もしあれば）
SELECT '=== 7. 日利処理のトリガー確認 ===' as section;
SELECT 'RPC関数のログはSupabase Dashboardで確認が必要' as note;

-- 8. 1NFTユーザーの12月日利合計
SELECT '=== 8. 1NFT保有ユーザーの12月日利合計（理論値確認） ===' as section;
SELECT
  SUM(profit_per_nft) as dec_total_per_nft
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31';
