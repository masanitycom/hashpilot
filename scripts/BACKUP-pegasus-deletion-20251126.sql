-- ペガサス個人利益削除前のバックアップ（2025-11-26）
-- 実行環境: 本番Supabase SQL Editor
-- 目的: 削除前の状態を保存し、必要に応じて復元できるようにする

-- =====================================
-- STEP 1: バックアップテーブルの作成
-- =====================================

-- 1-1: nft_daily_profit のバックアップ
CREATE TABLE IF NOT EXISTS nft_daily_profit_backup_20251126 AS
SELECT * FROM nft_daily_profit
WHERE user_id IN (
    SELECT user_id FROM users WHERE is_pegasus_exchange = TRUE
);

-- 1-2: affiliate_cycle のバックアップ
CREATE TABLE IF NOT EXISTS affiliate_cycle_backup_20251126 AS
SELECT * FROM affiliate_cycle
WHERE user_id IN (
    SELECT user_id FROM users WHERE is_pegasus_exchange = TRUE
);

-- =====================================
-- STEP 2: バックアップの確認
-- =====================================

-- 2-1: nft_daily_profit バックアップ件数
SELECT
    'nft_daily_profit_backup' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit_backup_20251126;

-- 2-2: affiliate_cycle バックアップ件数
SELECT
    'affiliate_cycle_backup' as table_name,
    COUNT(*) as record_count,
    SUM(available_usdt) as total_available_usdt,
    SUM(cum_usdt) as total_cum_usdt
FROM affiliate_cycle_backup_20251126;

-- =====================================
-- STEP 3: 元データとの比較確認
-- =====================================

-- 3-1: nft_daily_profit 比較
SELECT
    '元データ' as source,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id IN (SELECT user_id FROM users WHERE is_pegasus_exchange = TRUE)

UNION ALL

SELECT
    'バックアップ' as source,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit_backup_20251126;

-- 3-2: affiliate_cycle 比較
SELECT
    '元データ' as source,
    COUNT(*) as record_count,
    SUM(available_usdt) as total_available_usdt,
    SUM(cum_usdt) as total_cum_usdt
FROM affiliate_cycle
WHERE user_id IN (SELECT user_id FROM users WHERE is_pegasus_exchange = TRUE)

UNION ALL

SELECT
    'バックアップ' as source,
    COUNT(*) as record_count,
    SUM(available_usdt) as total_available_usdt,
    SUM(cum_usdt) as total_cum_usdt
FROM affiliate_cycle_backup_20251126;

-- =====================================
-- STEP 4: 復元用SQL（必要時のみ実行）
-- =====================================

-- ⚠️ 以下は削除後に問題が発生した場合のみ実行してください

-- 4-1: nft_daily_profit を復元
-- DELETE FROM nft_daily_profit
-- WHERE user_id IN (SELECT user_id FROM users WHERE is_pegasus_exchange = TRUE);
--
-- INSERT INTO nft_daily_profit
-- SELECT * FROM nft_daily_profit_backup_20251126;

-- 4-2: affiliate_cycle を復元
-- UPDATE affiliate_cycle ac
-- SET
--     available_usdt = bak.available_usdt,
--     cum_usdt = bak.cum_usdt,
--     phase = bak.phase,
--     updated_at = NOW()
-- FROM affiliate_cycle_backup_20251126 bak
-- WHERE ac.user_id = bak.user_id;

-- =====================================
-- STEP 5: バックアップテーブルの削除（復元不要な場合）
-- =====================================

-- ⚠️ 削除が成功し、問題がないことを確認した後のみ実行してください
--
-- DROP TABLE IF EXISTS nft_daily_profit_backup_20251126;
-- DROP TABLE IF EXISTS affiliate_cycle_backup_20251126;
