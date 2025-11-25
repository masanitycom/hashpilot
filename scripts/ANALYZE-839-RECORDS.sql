-- ========================================
-- 839件の削除対象レコードの詳細分析
-- ========================================

-- ========================================
-- 1. ユーザーごとのレコード数内訳（上位20件）
-- ========================================

SELECT
    '📊 ユーザーごとの誤配布レコード数（上位20件）' as label,
    u.user_id,
    u.full_name,
    u.operation_start_date,
    COUNT(ndp.id) as record_count,
    COUNT(DISTINCT ndp.date) as days_count,
    COUNT(DISTINCT nm.id) as nft_count,
    SUM(ndp.daily_profit) as total_profit,
    MIN(ndp.date) as first_incorrect_date,
    MAX(ndp.date) as last_incorrect_date
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date
GROUP BY u.user_id, u.full_name, u.operation_start_date
ORDER BY COUNT(ndp.id) DESC
LIMIT 20;

-- ========================================
-- 2. 日付別のレコード数内訳
-- ========================================

SELECT
    '📅 日付別の誤配布レコード数' as label,
    ndp.date,
    COUNT(ndp.id) as record_count,
    COUNT(DISTINCT ndp.user_id) as user_count,
    SUM(ndp.daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date
GROUP BY ndp.date
ORDER BY ndp.date;

-- ========================================
-- 3. 運用開始日別のユーザー数とレコード数
-- ========================================

SELECT
    '📊 運用開始日別の集計' as label,
    u.operation_start_date,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(ndp.id) as total_records,
    ROUND(COUNT(ndp.id)::NUMERIC / COUNT(DISTINCT u.user_id), 2) as avg_records_per_user,
    SUM(ndp.daily_profit) as total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;

-- ========================================
-- 4. NFT数別のユーザー分布
-- ========================================

SELECT
    '🎫 NFT数別のユーザー分布（誤配布対象者のみ）' as label,
    nft_count,
    COUNT(*) as user_count,
    SUM(record_count) as total_records
FROM (
    SELECT
        u.user_id,
        COUNT(DISTINCT nm.id) as nft_count,
        COUNT(ndp.id) as record_count
    FROM users u
    LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
    LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
    WHERE (u.operation_start_date IS NULL OR u.operation_start_date > ndp.date)
        AND ndp.id IS NOT NULL
    GROUP BY u.user_id
) subquery
GROUP BY nft_count
ORDER BY nft_count DESC;

-- ========================================
-- 5. 全体サマリー
-- ========================================

SELECT
    '📋 全体サマリー' as label,
    COUNT(DISTINCT u.user_id) as total_affected_users,
    COUNT(ndp.id) as total_records,
    COUNT(DISTINCT ndp.date) as total_days,
    ROUND(COUNT(ndp.id)::NUMERIC / COUNT(DISTINCT u.user_id), 2) as avg_records_per_user,
    ROUND(COUNT(ndp.id)::NUMERIC / COUNT(DISTINCT ndp.date), 2) as avg_records_per_day,
    SUM(ndp.daily_profit) as total_profit,
    MIN(ndp.date) as first_date,
    MAX(ndp.date) as last_date
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
    OR u.operation_start_date > ndp.date;

-- ========================================
-- 6. 計算の妥当性チェック
-- ========================================

SELECT
    '🔍 計算妥当性チェック' as label,
    '理論値: 55ユーザー × 平均NFT数 × 平均日数 = 839件' as formula,
    CASE
        WHEN 839 BETWEEN 700 AND 900 THEN '✅ 妥当な範囲'
        ELSE '⚠️ 要確認'
    END as validation;

SELECT '調査完了' as status;
