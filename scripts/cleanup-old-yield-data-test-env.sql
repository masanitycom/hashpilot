/* ========================================
   テスト環境の古い日利データクリーンアップ
   ======================================== */
-- 目的: 2025/11/1～11/5の％ベースの旧データを削除
-- 対象: daily_yield_log (旧システム)
-- 実行環境: テスト環境（staging）のSupabase

-- ========================================
-- Step 1: 削除対象データの確認
-- ========================================
SELECT
  'daily_yield_log' as table_name,
  date,
  yield_rate,
  margin_rate,
  user_rate
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-05'
ORDER BY date;

-- ========================================
-- Step 2: user_daily_profitの関連データを削除
-- ========================================
DELETE FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- ========================================
-- Step 3: user_referral_profitの関連データを削除
-- ========================================
DELETE FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- ========================================
-- Step 4: stock_fundの関連データを削除
-- ========================================
DELETE FROM stock_fund
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- ========================================
-- Step 5: nft_daily_profitの関連データを削除
-- ========================================
DELETE FROM nft_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- ========================================
-- Step 6: daily_yield_log（旧システム）を削除
-- ========================================
DELETE FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- ========================================
-- Step 7: affiliate_cycleのリセット（必要に応じて）
-- ========================================
-- 注意: この期間の紹介報酬をリセットする場合のみ実行
-- UPDATE affiliate_cycle
-- SET
--   cum_usdt = 0,
--   available_usdt = 0,
--   phase = 'USDT',
--   auto_nft_count = 0,
--   updated_at = NOW()
-- WHERE user_id IN (
--   SELECT DISTINCT user_id FROM user_referral_profit
--   WHERE date >= '2025-11-01' AND date <= '2025-11-05'
-- );

-- ========================================
-- 削除後の確認
-- ========================================
SELECT
  'daily_yield_log' as table_name,
  COUNT(*) as remaining_records
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

SELECT
  'user_daily_profit' as table_name,
  COUNT(*) as remaining_records
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

SELECT
  'nft_daily_profit' as table_name,
  COUNT(*) as remaining_records
FROM nft_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- ========================================
-- 完了メッセージ
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '✅ テスト環境の古い日利データ（2025/11/1～11/5）を削除しました';
  RAISE NOTICE '新しいv2システムで再度日利設定を行ってください';
END $$;
