-- ========================================
-- 包括的修正前のバックアップスクリプト
-- 実行日: 2026-01-13
-- ========================================
-- このスクリプトを先に実行してバックアップテーブルを作成
-- 修正後に問題があればRESTOREスクリプトで復元可能
-- ========================================

-- ========================================
-- BACKUP 1: 削除対象の自動NFT
-- ========================================
DROP TABLE IF EXISTS backup_nft_master_20260113;

CREATE TABLE backup_nft_master_20260113 AS
SELECT *
FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2026-01-01'
  AND EXTRACT(DAY FROM acquired_date) NOT IN (1, 28, 29, 30, 31);

SELECT '自動NFTバックアップ' as backup_type, COUNT(*) as records FROM backup_nft_master_20260113;

-- ========================================
-- BACKUP 2: 削除対象のpurchases
-- ========================================
DROP TABLE IF EXISTS backup_purchases_20260113;

CREATE TABLE backup_purchases_20260113 AS
SELECT *
FROM purchases
WHERE is_auto_purchase = true
  AND created_at >= '2026-01-01'
  AND EXTRACT(DAY FROM created_at::date) NOT IN (1, 28, 29, 30, 31);

SELECT 'purchasesバックアップ' as backup_type, COUNT(*) as records FROM backup_purchases_20260113;

-- ========================================
-- BACKUP 3: affiliate_cycle全体
-- ========================================
DROP TABLE IF EXISTS backup_affiliate_cycle_20260113;

CREATE TABLE backup_affiliate_cycle_20260113 AS
SELECT * FROM affiliate_cycle;

SELECT 'affiliate_cycleバックアップ' as backup_type, COUNT(*) as records FROM backup_affiliate_cycle_20260113;

-- ========================================
-- BACKUP 4: 1月の日次紹介報酬データ
-- ========================================
DROP TABLE IF EXISTS backup_user_referral_profit_jan_20260113;

CREATE TABLE backup_user_referral_profit_jan_20260113 AS
SELECT *
FROM user_referral_profit
WHERE date >= '2026-01-01';

SELECT '1月日次紹介報酬バックアップ' as backup_type, COUNT(*) as records FROM backup_user_referral_profit_jan_20260113;

-- ========================================
-- BACKUP 5: monthly_referral_profit全体（念のため）
-- ========================================
DROP TABLE IF EXISTS backup_monthly_referral_profit_20260113;

CREATE TABLE backup_monthly_referral_profit_20260113 AS
SELECT * FROM monthly_referral_profit;

SELECT 'monthly_referral_profitバックアップ' as backup_type, COUNT(*) as records FROM backup_monthly_referral_profit_20260113;

-- ========================================
-- バックアップ完了確認
-- ========================================
SELECT '=== バックアップ完了 ===' as status;

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

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'バックアップ完了';
  RAISE NOTICE '以下のテーブルが作成されました:';
  RAISE NOTICE '- backup_nft_master_20260113';
  RAISE NOTICE '- backup_purchases_20260113';
  RAISE NOTICE '- backup_affiliate_cycle_20260113';
  RAISE NOTICE '- backup_user_referral_profit_jan_20260113';
  RAISE NOTICE '- backup_monthly_referral_profit_20260113';
  RAISE NOTICE '========================================';
  RAISE NOTICE '次に FIX-COMPREHENSIVE-all-users-20260113.sql を実行してください';
  RAISE NOTICE '========================================';
END $$;
