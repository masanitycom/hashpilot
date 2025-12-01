-- ========================================
-- V2移行前のデータベースバックアップ
-- ========================================
-- 実行日時: 2025-12-01
-- 目的: V2システムに切り替える前に重要データをバックアップ
--
-- 使い方:
-- 1. このSQLをSupabase SQL Editorで実行
-- 2. 結果をCSVまたはJSONでエクスポート
-- 3. ローカルに保存
-- ========================================

-- ========================================
-- 1. affiliate_cycle テーブル（最重要）
-- ========================================
SELECT '=== 1. affiliate_cycle バックアップ ===' as section;

SELECT
    user_id,
    available_usdt,
    cum_usdt,
    phase,
    auto_nft_count,
    manual_nft_count,
    updated_at,
    created_at
FROM affiliate_cycle
ORDER BY user_id;

-- レコード数確認
SELECT 'affiliate_cycle レコード数:' as info, COUNT(*) as count FROM affiliate_cycle;

-- ========================================
-- 2. user_daily_profit テーブル（11月分）
-- ========================================
SELECT '=== 2. user_daily_profit バックアップ（11月） ===' as section;

SELECT
    user_id,
    date,
    daily_profit,
    phase,
    created_at
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date DESC, user_id;

-- レコード数確認
SELECT 'user_daily_profit（11月）レコード数:' as info, COUNT(*) as count
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

-- ========================================
-- 3. user_referral_profit テーブル（11月分）
-- ========================================
SELECT '=== 3. user_referral_profit バックアップ（11月） ===' as section;

SELECT
    user_id,
    date,
    referral_level,
    child_user_id,
    profit_amount,
    created_at
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date DESC, user_id, referral_level;

-- レコード数確認
SELECT 'user_referral_profit（11月）レコード数:' as info, COUNT(*) as count
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

-- ========================================
-- 4. nft_daily_profit テーブル（11月分）
-- ========================================
SELECT '=== 4. nft_daily_profit バックアップ（11月） ===' as section;

SELECT
    nft_id,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM nft_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date DESC, user_id, nft_id;

-- レコード数確認
SELECT 'nft_daily_profit（11月）レコード数:' as info, COUNT(*) as count
FROM nft_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

-- ========================================
-- 5. daily_yield_log テーブル（V1ログ、11月分）
-- ========================================
SELECT '=== 5. daily_yield_log バックアップ（11月） ===' as section;

SELECT
    date,
    yield_rate,
    margin_rate,
    total_users,
    total_distributed,
    total_referral_profit,
    total_auto_nft,
    created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date DESC;

-- レコード数確認
SELECT 'daily_yield_log（11月）レコード数:' as info, COUNT(*) as count
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

-- ========================================
-- 6. users テーブル（has_approved_nft = true のみ）
-- ========================================
SELECT '=== 6. users バックアップ（承認済みユーザーのみ） ===' as section;

SELECT
    user_id,
    email,
    full_name,
    referrer_user_id,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    is_operation_only,
    total_purchases,
    created_at
FROM users
WHERE has_approved_nft = true
ORDER BY user_id;

-- レコード数確認
SELECT 'users（承認済み）レコード数:' as info, COUNT(*) as count
FROM users
WHERE has_approved_nft = true;

-- ========================================
-- 7. nft_master テーブル（buyback_date IS NULL のみ）
-- ========================================
SELECT '=== 7. nft_master バックアップ（有効なNFTのみ） ===' as section;

SELECT
    id,
    user_id,
    nft_type,
    acquired_date,
    buyback_date,
    nft_value,
    created_at
FROM nft_master
WHERE buyback_date IS NULL
ORDER BY user_id, acquired_date;

-- レコード数確認
SELECT 'nft_master（有効）レコード数:' as info, COUNT(*) as count
FROM nft_master
WHERE buyback_date IS NULL;

-- ========================================
-- 8. サマリー情報
-- ========================================
SELECT '=== 8. バックアップサマリー ===' as section;

WITH summary AS (
    SELECT
        'affiliate_cycle' as table_name,
        COUNT(*) as record_count,
        SUM(available_usdt) as total_available_usdt,
        SUM(cum_usdt) as total_cum_usdt
    FROM affiliate_cycle
    UNION ALL
    SELECT
        'user_daily_profit (11月)' as table_name,
        COUNT(*) as record_count,
        SUM(daily_profit) as total_profit,
        NULL as total_cum_usdt
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    UNION ALL
    SELECT
        'user_referral_profit (11月)' as table_name,
        COUNT(*) as record_count,
        SUM(profit_amount) as total_profit,
        NULL as total_cum_usdt
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    UNION ALL
    SELECT
        'nft_daily_profit (11月)' as table_name,
        COUNT(*) as record_count,
        SUM(daily_profit) as total_profit,
        NULL as total_cum_usdt
    FROM nft_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    UNION ALL
    SELECT
        'users (承認済み)' as table_name,
        COUNT(*) as record_count,
        NULL as total_profit,
        NULL as total_cum_usdt
    FROM users
    WHERE has_approved_nft = true
    UNION ALL
    SELECT
        'nft_master (有効)' as table_name,
        COUNT(*) as record_count,
        NULL as total_profit,
        NULL as total_cum_usdt
    FROM nft_master
    WHERE buyback_date IS NULL
)
SELECT
    table_name,
    record_count,
    COALESCE(total_available_usdt, total_profit) as total_amount,
    total_cum_usdt
FROM summary;

-- ========================================
-- 9. 重要な整合性チェック
-- ========================================
SELECT '=== 9. データ整合性チェック ===' as section;

-- 9-1. affiliate_cycleに存在するが、usersに存在しないユーザー
SELECT '9-1. 孤立したaffiliate_cycleレコード（エラー）' as check_name;
SELECT ac.user_id, ac.available_usdt, ac.cum_usdt
FROM affiliate_cycle ac
LEFT JOIN users u ON ac.user_id = u.user_id
WHERE u.user_id IS NULL;

-- 9-2. NFTがあるのにaffiliate_cycleがないユーザー
SELECT '9-2. NFTがあるのにaffiliate_cycleがないユーザー（エラー）' as check_name;
SELECT DISTINCT nm.user_id, COUNT(nm.id) as nft_count
FROM nft_master nm
LEFT JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.buyback_date IS NULL
  AND ac.user_id IS NULL
GROUP BY nm.user_id;

-- 9-3. 11月の日利と紹介報酬の合計が一致するか
SELECT '9-3. 11月の配布額チェック' as check_name;
WITH daily_total AS (
    SELECT COALESCE(SUM(daily_profit), 0) as total
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
),
referral_total AS (
    SELECT COALESCE(SUM(profit_amount), 0) as total
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
)
SELECT
    dt.total as daily_profit_total,
    rt.total as referral_profit_total,
    (dt.total + rt.total) as grand_total
FROM daily_total dt, referral_total rt;

-- ========================================
-- 完了メッセージ
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ バックアップ完了';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '実行日時: %', NOW();
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '1. 上記のクエリ結果をすべてエクスポート（CSV/JSON）';
    RAISE NOTICE '2. ローカルに保存（推奨: D:\HASHPILOT\backups\）';
    RAISE NOTICE '3. V2関数をデプロイ';
    RAISE NOTICE '=========================================';
END $$;
