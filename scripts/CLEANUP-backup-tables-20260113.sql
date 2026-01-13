-- ========================================
-- バックアップテーブルのクリーンアップ
-- 実行日: 2026-01-13
-- ========================================
-- ⚠️ 警告: 修正が正常に完了したことを確認後に実行
-- バックアップを削除すると復元できなくなります
-- ========================================

-- 確認プロンプト
SELECT '=== バックアップテーブル削除前の確認 ===' as warning;

SELECT
  'backup_nft_master_20260113' as table_name,
  COUNT(*) as records
FROM backup_nft_master_20260113
UNION ALL
SELECT
  'backup_purchases_20260113' as table_name,
  COUNT(*) as records
FROM backup_purchases_20260113
UNION ALL
SELECT
  'backup_affiliate_cycle_20260113' as table_name,
  COUNT(*) as records
FROM backup_affiliate_cycle_20260113
UNION ALL
SELECT
  'backup_user_referral_profit_jan_20260113' as table_name,
  COUNT(*) as records
FROM backup_user_referral_profit_jan_20260113
UNION ALL
SELECT
  'backup_monthly_referral_profit_20260113' as table_name,
  COUNT(*) as records
FROM backup_monthly_referral_profit_20260113;

-- ========================================
-- 以下のDROP文を実行するとバックアップが削除されます
-- 修正完了を確認してから実行してください
-- ========================================

DROP TABLE IF EXISTS backup_nft_master_20260113;
DROP TABLE IF EXISTS backup_purchases_20260113;
DROP TABLE IF EXISTS backup_affiliate_cycle_20260113;
DROP TABLE IF EXISTS backup_user_referral_profit_jan_20260113;
DROP TABLE IF EXISTS backup_monthly_referral_profit_20260113;

SELECT '=== バックアップテーブル削除完了 ===' as status;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'バックアップテーブルを削除しました';
  RAISE NOTICE '========================================';
END $$;
