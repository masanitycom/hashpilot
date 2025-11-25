-- ========================================
-- バックアップからの復元スクリプト
-- ========================================
-- ⚠️ このスクリプトは緊急時のみ使用してください
-- ⚠️ 実行前に必ず内容を確認してください
-- ========================================

-- ========================================
-- 使用方法
-- ========================================
-- 1. 復元したいテーブルのコメントを外す
-- 2. BEGIN; から COMMIT; までを実行
-- 3. 結果を確認してからCOMMIT
-- 4. 問題があればROLLBACKを実行
-- ========================================

-- ========================================
-- 全テーブルの復元（最も危険）
-- ========================================
/*
BEGIN;

-- usersテーブルの復元
TRUNCATE TABLE public.users CASCADE;
INSERT INTO public.users
SELECT * FROM backup_20251115.users;

-- nft_daily_profitテーブルの復元
TRUNCATE TABLE public.nft_daily_profit CASCADE;
INSERT INTO public.nft_daily_profit
SELECT * FROM backup_20251115.nft_daily_profit;

-- user_referral_profitテーブルの復元
TRUNCATE TABLE public.user_referral_profit CASCADE;
INSERT INTO public.user_referral_profit
SELECT * FROM backup_20251115.user_referral_profit;

-- affiliate_cycleテーブルの復元
TRUNCATE TABLE public.affiliate_cycle CASCADE;
INSERT INTO public.affiliate_cycle
SELECT * FROM backup_20251115.affiliate_cycle;

-- nft_masterテーブルの復元
TRUNCATE TABLE public.nft_master CASCADE;
INSERT INTO public.nft_master
SELECT * FROM backup_20251115.nft_master;

-- purchasesテーブルの復元
TRUNCATE TABLE public.purchases CASCADE;
INSERT INTO public.purchases
SELECT * FROM backup_20251115.purchases;

-- 復元の確認
SELECT
    'users' as table_name,
    COUNT(*) as current_count,
    (SELECT COUNT(*) FROM backup_20251115.users) as backup_count
FROM public.users
UNION ALL
SELECT 'nft_daily_profit', COUNT(*), (SELECT COUNT(*) FROM backup_20251115.nft_daily_profit)
FROM public.nft_daily_profit
UNION ALL
SELECT 'user_referral_profit', COUNT(*), (SELECT COUNT(*) FROM backup_20251115.user_referral_profit)
FROM public.user_referral_profit
UNION ALL
SELECT 'affiliate_cycle', COUNT(*), (SELECT COUNT(*) FROM backup_20251115.affiliate_cycle)
FROM public.affiliate_cycle
UNION ALL
SELECT 'nft_master', COUNT(*), (SELECT COUNT(*) FROM backup_20251115.nft_master)
FROM public.nft_master
UNION ALL
SELECT 'purchases', COUNT(*), (SELECT COUNT(*) FROM backup_20251115.purchases)
FROM public.purchases;

-- 問題がなければコミット、問題があればロールバック
-- COMMIT;
ROLLBACK; -- デフォルトはロールバック
*/

-- ========================================
-- 個別テーブルの復元（より安全）
-- ========================================

-- usersテーブルのみ復元
/*
BEGIN;

TRUNCATE TABLE public.users CASCADE;
INSERT INTO public.users
SELECT * FROM backup_20251115.users;

SELECT '✅ users復元完了' as status, COUNT(*) as record_count FROM public.users;

-- COMMIT;
ROLLBACK;
*/

-- nft_daily_profitテーブルのみ復元
/*
BEGIN;

TRUNCATE TABLE public.nft_daily_profit CASCADE;
INSERT INTO public.nft_daily_profit
SELECT * FROM backup_20251115.nft_daily_profit;

SELECT '✅ nft_daily_profit復元完了' as status, COUNT(*) as record_count FROM public.nft_daily_profit;

-- COMMIT;
ROLLBACK;
*/

-- user_referral_profitテーブルのみ復元
/*
BEGIN;

TRUNCATE TABLE public.user_referral_profit CASCADE;
INSERT INTO public.user_referral_profit
SELECT * FROM backup_20251115.user_referral_profit;

SELECT '✅ user_referral_profit復元完了' as status, COUNT(*) as record_count FROM public.user_referral_profit;

-- COMMIT;
ROLLBACK;
*/

-- affiliate_cycleテーブルのみ復元
/*
BEGIN;

TRUNCATE TABLE public.affiliate_cycle CASCADE;
INSERT INTO public.affiliate_cycle
SELECT * FROM backup_20251115.affiliate_cycle;

SELECT '✅ affiliate_cycle復元完了' as status, COUNT(*) as record_count FROM public.affiliate_cycle;

-- COMMIT;
ROLLBACK;
*/

-- nft_masterテーブルのみ復元
/*
BEGIN;

TRUNCATE TABLE public.nft_master CASCADE;
INSERT INTO public.nft_master
SELECT * FROM backup_20251115.nft_master;

SELECT '✅ nft_master復元完了' as status, COUNT(*) as record_count FROM public.nft_master;

-- COMMIT;
ROLLBACK;
*/

-- purchasesテーブルのみ復元
/*
BEGIN;

TRUNCATE TABLE public.purchases CASCADE;
INSERT INTO public.purchases
SELECT * FROM backup_20251115.purchases;

SELECT '✅ purchases復元完了' as status, COUNT(*) as record_count FROM public.purchases;

-- COMMIT;
ROLLBACK;
*/

-- ========================================
-- 特定のユーザーのデータのみ復元
-- ========================================

-- 特定のユーザーのaffiliate_cycleを復元
/*
BEGIN;

-- 例: ユーザー7A9637のaffiliate_cycleを復元
DELETE FROM public.affiliate_cycle WHERE user_id = '7A9637';
INSERT INTO public.affiliate_cycle
SELECT * FROM backup_20251115.affiliate_cycle
WHERE user_id = '7A9637';

SELECT '✅ 特定ユーザーのaffiliate_cycle復元完了' as status,
       user_id, cum_usdt, available_usdt
FROM public.affiliate_cycle
WHERE user_id = '7A9637';

-- COMMIT;
ROLLBACK;
*/

-- ========================================
-- バックアップの削除（ディスク容量が必要な場合）
-- ========================================
-- ⚠️ バックアップを削除する前に、復元が不要であることを確認してください
/*
DROP SCHEMA IF EXISTS backup_20251115 CASCADE;
SELECT '✅ バックアップスキーマ削除完了' as status;
*/

-- ========================================
-- 注意事項
-- ========================================
-- 1. 必ず復元前にROLLBACKで動作確認してください
-- 2. 復元後は必ずデータを確認してください
-- 3. TRUNCATEはカスケード削除されるので注意
-- 4. 外部キー制約がある場合は順序に注意
-- 5. 不明な点があれば実行しないでください
