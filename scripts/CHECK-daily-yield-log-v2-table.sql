-- ========================================
-- daily_yield_log_v2テーブルの存在確認
-- ========================================

-- 1. テーブルが存在するか確認
SELECT '=== 1. daily_yield_log_v2テーブルの存在確認 ===' as section;

SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%daily_yield_log%'
ORDER BY table_name;

-- 2. daily_yield_log_v2のカラム構成
SELECT '=== 2. daily_yield_log_v2のカラム構成 ===' as section;

SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'daily_yield_log_v2'
ORDER BY ordinal_position;

-- 3. daily_yield_log_v2の全データ（最新10件）
SELECT '=== 3. daily_yield_log_v2の全データ（最新10件） ===' as section;

SELECT
    date,
    total_profit_amount,
    daily_pnl,
    distribution_dividend,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- 4. daily_yield_logテーブル（V1）の確認
SELECT '=== 4. daily_yield_logテーブル（V1）の確認 ===' as section;

SELECT
    date,
    yield_rate,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

-- 5. 11月のログデータ（V1とV2両方）
SELECT '=== 5. 11月のログデータ ===' as section;

SELECT
    'V1 (daily_yield_log)' as log_type,
    COUNT(*) as record_count,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM daily_yield_log
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30'
UNION ALL
SELECT
    'V2 (daily_yield_log_v2)' as log_type,
    COUNT(*) as record_count,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM daily_yield_log_v2
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30';

-- サマリー
DO $$
DECLARE
    v_v2_table_exists BOOLEAN;
    v_v2_count INTEGER;
    v_v1_count INTEGER;
BEGIN
    -- daily_yield_log_v2が存在するか
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = 'daily_yield_log_v2'
    ) INTO v_v2_table_exists;

    IF v_v2_table_exists THEN
        SELECT COUNT(*) INTO v_v2_count
        FROM daily_yield_log_v2
        WHERE date >= '2025-11-01' AND date <= '2025-11-30';

        SELECT COUNT(*) INTO v_v1_count
        FROM daily_yield_log
        WHERE date >= '2025-11-01' AND date <= '2025-11-30';

        RAISE NOTICE '===========================================';
        RAISE NOTICE '📊 ログテーブルの状況';
        RAISE NOTICE '===========================================';
        RAISE NOTICE 'daily_yield_log_v2テーブル: 存在する';
        RAISE NOTICE '  11月のレコード数: %件', v_v2_count;
        RAISE NOTICE '';
        RAISE NOTICE 'daily_yield_logテーブル（V1）:';
        RAISE NOTICE '  11月のレコード数: %件', v_v1_count;
        RAISE NOTICE '';
        IF v_v2_count = 0 AND v_v1_count > 0 THEN
            RAISE NOTICE '🚨 問題:';
            RAISE NOTICE '  V2テーブルにデータなし、V1テーブルにはデータあり';
            RAISE NOTICE '  → V1関数が実行されている可能性';
        ELSIF v_v2_count = 0 AND v_v1_count = 0 THEN
            RAISE NOTICE '🚨 問題:';
            RAISE NOTICE '  V1、V2両方のテーブルにデータなし';
            RAISE NOTICE '  → 日利処理が実行されていない';
        ELSE
            RAISE NOTICE '✅ V2テーブルにデータあり';
        END IF;
        RAISE NOTICE '===========================================';
    ELSE
        RAISE NOTICE '===========================================';
        RAISE NOTICE '🚨 重大な問題';
        RAISE NOTICE '===========================================';
        RAISE NOTICE 'daily_yield_log_v2テーブルが存在しません！';
        RAISE NOTICE '===========================================';
    END IF;
END $$;
