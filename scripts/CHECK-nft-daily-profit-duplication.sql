-- ========================================
-- nft_daily_profitテーブルの重複確認
-- ========================================

-- 1. 11/30のnft_daily_profitレコード数
SELECT '=== 1. 11/30のnft_daily_profitレコード数 ===' as section;

SELECT
    COUNT(*) as record_count,
    COUNT(DISTINCT nft_id) as unique_nft_count,
    COUNT(DISTINCT user_id) as unique_user_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date = '2025-11-30';

-- 2. 11/30のuser_daily_profitレコード数（比較用）
SELECT '=== 2. 11/30のuser_daily_profitレコード数 ===' as section;

SELECT
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as unique_user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-11-30';

-- 3. nft_daily_profitに重複レコードがあるか
SELECT '=== 3. nft_daily_profitの重複確認 ===' as section;

SELECT
    nft_id,
    user_id,
    date,
    COUNT(*) as duplicate_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date = '2025-11-30'
GROUP BY nft_id, user_id, date
HAVING COUNT(*) > 1;

-- 4. 同じnft_idで異なる金額が記録されているか
SELECT '=== 4. 同じNFTで異なる金額（サンプル10件） ===' as section;

SELECT
    nft_id,
    user_id,
    date,
    daily_profit,
    COUNT(*) OVER (PARTITION BY nft_id, date) as record_count
FROM nft_daily_profit
WHERE date = '2025-11-30'
  AND nft_id IN (
      SELECT nft_id
      FROM nft_daily_profit
      WHERE date = '2025-11-30'
      GROUP BY nft_id
      HAVING COUNT(*) > 1
  )
ORDER BY nft_id, daily_profit
LIMIT 10;

-- 5. user_daily_profitとの整合性確認
SELECT '=== 5. user_daily_profit vs nft_daily_profitの整合性 ===' as section;

WITH nft_aggregated AS (
    SELECT
        user_id,
        SUM(daily_profit) as nft_total
    FROM nft_daily_profit
    WHERE date = '2025-11-30'
    GROUP BY user_id
),
user_total AS (
    SELECT
        user_id,
        daily_profit as user_total
    FROM user_daily_profit
    WHERE date = '2025-11-30'
)
SELECT
    COALESCE(na.user_id, ut.user_id) as user_id,
    na.nft_total,
    ut.user_total,
    (na.nft_total - ut.user_total) as difference
FROM nft_aggregated na
FULL OUTER JOIN user_total ut ON na.user_id = ut.user_id
WHERE ABS(COALESCE(na.nft_total, 0) - COALESCE(ut.user_total, 0)) > 0.01
ORDER BY ABS(COALESCE(na.nft_total, 0) - COALESCE(ut.user_total, 0)) DESC
LIMIT 20;

-- 6. 11月全体のnft_daily_profit合計
SELECT '=== 6. 11月全体のnft_daily_profit合計 ===' as section;

SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT nft_id) as unique_nfts,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT date) as unique_dates,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30';

-- 7. 11月全体のuser_daily_profit合計（比較）
SELECT '=== 7. 11月全体のuser_daily_profit合計 ===' as section;

SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT date) as unique_dates,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30';

-- サマリー
DO $$
DECLARE
    v_nft_total NUMERIC;
    v_user_total NUMERIC;
    v_nft_count INTEGER;
    v_user_count INTEGER;
BEGIN
    -- nft_daily_profitの合計
    SELECT SUM(daily_profit), COUNT(*)
    INTO v_nft_total, v_nft_count
    FROM nft_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    -- user_daily_profitの合計
    SELECT SUM(daily_profit), COUNT(*)
    INTO v_user_total, v_user_count
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 nft_daily_profit vs user_daily_profit';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'nft_daily_profit:';
    RAISE NOTICE '  レコード数: %', v_nft_count;
    RAISE NOTICE '  合計金額: $%', v_nft_total;
    RAISE NOTICE '';
    RAISE NOTICE 'user_daily_profit:';
    RAISE NOTICE '  レコード数: %', v_user_count;
    RAISE NOTICE '  合計金額: $%', v_user_total;
    RAISE NOTICE '';
    IF ABS(v_nft_total - v_user_total) < 1 THEN
        RAISE NOTICE '✅ 2つのテーブルは一致しています';
    ELSE
        RAISE NOTICE '🚨 差額: $%', ABS(v_nft_total - v_user_total);
    END IF;
    RAISE NOTICE '===========================================';
END $$;
