-- ========================================
-- STEP 1: 本番環境のバックアップ作成
-- ========================================
-- このスクリプトをSupabase SQL Editorで実行してください
-- ========================================

-- ========================================
-- 1. バックアップ用スキーマの作成
-- ========================================
CREATE SCHEMA IF NOT EXISTS backup_20251115;

SELECT '✅ バックアップスキーマ作成完了: backup_20251115' as status;

-- ========================================
-- 2. 各テーブルのバックアップ作成
-- ========================================

-- usersテーブルのバックアップ
DROP TABLE IF EXISTS backup_20251115.users;
CREATE TABLE backup_20251115.users AS
SELECT * FROM public.users;

SELECT '✅ usersテーブルのバックアップ完了' as status,
       COUNT(*) as record_count
FROM backup_20251115.users;

-- nft_daily_profitテーブルのバックアップ
DROP TABLE IF EXISTS backup_20251115.nft_daily_profit;
CREATE TABLE backup_20251115.nft_daily_profit AS
SELECT * FROM public.nft_daily_profit;

SELECT '✅ nft_daily_profitテーブルのバックアップ完了' as status,
       COUNT(*) as record_count
FROM backup_20251115.nft_daily_profit;

-- user_referral_profitテーブルのバックアップ
DROP TABLE IF EXISTS backup_20251115.user_referral_profit;
CREATE TABLE backup_20251115.user_referral_profit AS
SELECT * FROM public.user_referral_profit;

SELECT '✅ user_referral_profitテーブルのバックアップ完了' as status,
       COUNT(*) as record_count
FROM backup_20251115.user_referral_profit;

-- affiliate_cycleテーブルのバックアップ
DROP TABLE IF EXISTS backup_20251115.affiliate_cycle;
CREATE TABLE backup_20251115.affiliate_cycle AS
SELECT * FROM public.affiliate_cycle;

SELECT '✅ affiliate_cycleテーブルのバックアップ完了' as status,
       COUNT(*) as record_count
FROM backup_20251115.affiliate_cycle;

-- nft_masterテーブルのバックアップ
DROP TABLE IF EXISTS backup_20251115.nft_master;
CREATE TABLE backup_20251115.nft_master AS
SELECT * FROM public.nft_master;

SELECT '✅ nft_masterテーブルのバックアップ完了' as status,
       COUNT(*) as record_count
FROM backup_20251115.nft_master;

-- purchasesテーブルのバックアップ
DROP TABLE IF EXISTS backup_20251115.purchases;
CREATE TABLE backup_20251115.purchases AS
SELECT * FROM public.purchases;

SELECT '✅ purchasesテーブルのバックアップ完了' as status,
       COUNT(*) as record_count
FROM backup_20251115.purchases;

-- ========================================
-- 3. バックアップの確認
-- ========================================

-- バックアップされたテーブルの一覧とサイズ
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'backup_20251115'
ORDER BY tablename;

-- 各テーブルのレコード数比較
SELECT
    'users' as table_name,
    (SELECT COUNT(*) FROM public.users) as original_count,
    (SELECT COUNT(*) FROM backup_20251115.users) as backup_count,
    CASE
        WHEN (SELECT COUNT(*) FROM public.users) = (SELECT COUNT(*) FROM backup_20251115.users)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
UNION ALL
SELECT
    'nft_daily_profit',
    (SELECT COUNT(*) FROM public.nft_daily_profit),
    (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit),
    CASE
        WHEN (SELECT COUNT(*) FROM public.nft_daily_profit) = (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END
UNION ALL
SELECT
    'user_referral_profit',
    (SELECT COUNT(*) FROM public.user_referral_profit),
    (SELECT COUNT(*) FROM backup_20251115.user_referral_profit),
    CASE
        WHEN (SELECT COUNT(*) FROM public.user_referral_profit) = (SELECT COUNT(*) FROM backup_20251115.user_referral_profit)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END
UNION ALL
SELECT
    'affiliate_cycle',
    (SELECT COUNT(*) FROM public.affiliate_cycle),
    (SELECT COUNT(*) FROM backup_20251115.affiliate_cycle),
    CASE
        WHEN (SELECT COUNT(*) FROM public.affiliate_cycle) = (SELECT COUNT(*) FROM backup_20251115.affiliate_cycle)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END
UNION ALL
SELECT
    'nft_master',
    (SELECT COUNT(*) FROM public.nft_master),
    (SELECT COUNT(*) FROM backup_20251115.nft_master),
    CASE
        WHEN (SELECT COUNT(*) FROM public.nft_master) = (SELECT COUNT(*) FROM backup_20251115.nft_master)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END
UNION ALL
SELECT
    'purchases',
    (SELECT COUNT(*) FROM public.purchases),
    (SELECT COUNT(*) FROM backup_20251115.purchases),
    CASE
        WHEN (SELECT COUNT(*) FROM public.purchases) = (SELECT COUNT(*) FROM backup_20251115.purchases)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END;

-- ========================================
-- 4. バックアップ完了メッセージ
-- ========================================
SELECT
    '✅✅✅ バックアップ作成完了 ✅✅✅' as status,
    'backup_20251115' as schema_name,
    COUNT(DISTINCT tablename) as table_count,
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename))) as total_size
FROM pg_tables
WHERE schemaname = 'backup_20251115';

-- ========================================
-- 重要: すべてのステータスが「✅ 一致」であることを確認してください
-- 確認後、次のステップ（STEP2-CHECK-INCORRECT-DISTRIBUTION.sql）に進んでください
-- ========================================
