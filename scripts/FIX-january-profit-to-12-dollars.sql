-- ========================================
-- 1月度個人利益を約$12/NFTに調整
-- ========================================
-- 目的: 1NFTあたりの月間個人利益を$1.2 → $12に変更
--
-- 作業手順:
-- 1. 現状確認
-- 2. 関数バグ修正（上書き時のcum_usdt二重加算防止）
-- 3. 日利データの調整
-- 4. nft_daily_profit再計算
-- 5. affiliate_cycle再計算
-- 6. 紹介報酬再計算
-- 7. 月末出金データ再作成
-- ========================================

-- ========================================
-- STEP 1: 現状確認
-- ========================================
SELECT '=== STEP 1: 現状確認 ===' as section;

-- 1月の日利ログサマリー
SELECT
  '1月日利サマリー' as info,
  COUNT(*) as 日数,
  SUM(total_profit_amount) as 運用利益合計,
  SUM(distribution_dividend) as 配当合計_60pct,
  (SELECT COUNT(*) FROM nft_master nm
   JOIN users u ON nm.user_id = u.user_id
   WHERE nm.buyback_date IS NULL
     AND nm.operation_start_date <= '2026-01-31'
     AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  ) as 現在のNFT数
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-31';

-- 0D4493（1NFT）の現在の1月個人利益
SELECT
  '0D4493の1月個人利益' as info,
  ROUND(SUM(daily_profit)::numeric, 3) as 現在の個人利益
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2026-01-01'
  AND date <= '2026-01-31';

-- ========================================
-- STEP 2: 目標計算
-- ========================================
SELECT '=== STEP 2: 目標計算 ===' as section;

-- 現在の配当合計と目標を計算
WITH current_stats AS (
  SELECT
    SUM(distribution_dividend) as current_total_dividend,
    -- 1月の平均NFT数を概算（簡易計算）
    (SELECT AVG(total_nft_count) FROM daily_yield_log_v2
     WHERE date >= '2026-01-01' AND date <= '2026-01-31') as avg_nft_count
  FROM daily_yield_log_v2
  WHERE date >= '2026-01-01' AND date <= '2026-01-31'
)
SELECT
  '目標計算' as info,
  ROUND(current_total_dividend::numeric, 2) as 現在の配当合計,
  ROUND((current_total_dividend / avg_nft_count)::numeric, 3) as 現在のNFT単価,
  ROUND((avg_nft_count * 12)::numeric, 2) as 目標配当合計_12ドル,
  ROUND((avg_nft_count * 12 - current_total_dividend)::numeric, 2) as 必要な増加額
FROM current_stats;
