-- ========================================
-- テスト環境の古い日利データクリーンアップ（シンプル版）
-- 2025/11/1～11/5のデータを削除
-- ========================================

-- Step 1: 関連データを削除
DELETE FROM user_daily_profit WHERE date >= '2025-11-01' AND date <= '2025-11-05';
DELETE FROM user_referral_profit WHERE date >= '2025-11-01' AND date <= '2025-11-05';
DELETE FROM stock_fund WHERE date >= '2025-11-01' AND date <= '2025-11-05';
DELETE FROM nft_daily_profit WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- Step 2: 旧システムの日利ログを削除
DELETE FROM daily_yield_log WHERE date >= '2025-11-01' AND date <= '2025-11-05';

-- Step 3: 確認
SELECT
  '削除完了' as status,
  (SELECT COUNT(*) FROM daily_yield_log WHERE date >= '2025-11-01' AND date <= '2025-11-05') as daily_yield_log_remaining,
  (SELECT COUNT(*) FROM user_daily_profit WHERE date >= '2025-11-01' AND date <= '2025-11-05') as user_daily_profit_remaining,
  (SELECT COUNT(*) FROM nft_daily_profit WHERE date >= '2025-11-01' AND date <= '2025-11-05') as nft_daily_profit_remaining;
