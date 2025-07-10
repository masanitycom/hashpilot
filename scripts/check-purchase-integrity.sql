-- 全ユーザーの購入額整合性チェック

-- 1. 差額があるユーザーを検出
CREATE OR REPLACE VIEW purchase_integrity_check AS
WITH actual_purchases AS (
    SELECT 
        user_id,
        COUNT(*) as purchase_count,
        SUM(CASE WHEN admin_approved THEN amount_usd ELSE 0 END) as approved_total,
        SUM(amount_usd) as all_purchases_total,
        COUNT(CASE WHEN admin_approved THEN 1 END) as approved_count
    FROM purchases
    GROUP BY user_id
),
user_comparison AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases as recorded_amount,
        COALESCE(ap.approved_total, 0) as actual_approved_amount,
        COALESCE(ap.all_purchases_total, 0) as all_purchases_amount,
        COALESCE(ap.purchase_count, 0) as purchase_count,
        COALESCE(ap.approved_count, 0) as approved_count,
        u.total_purchases - COALESCE(ap.approved_total, 0) as difference
    FROM users u
    LEFT JOIN actual_purchases ap ON u.user_id = ap.user_id
    WHERE u.total_purchases > 0 OR ap.approved_total > 0
)
SELECT 
    *,
    CASE 
        WHEN ABS(difference) < 0.01 THEN 'OK'
        WHEN difference > 0 THEN 'OVER_RECORDED'
        WHEN difference < 0 THEN 'UNDER_RECORDED'
    END as status
FROM user_comparison
ORDER BY ABS(difference) DESC;

-- 2. 差額があるユーザーのサマリー
SELECT 'INTEGRITY CHECK SUMMARY' as report_type;
SELECT 
    status,
    COUNT(*) as user_count,
    SUM(ABS(difference)) as total_difference
FROM purchase_integrity_check
GROUP BY status;

-- 3. 大きな差額があるユーザーTOP10
SELECT 'TOP 10 DISCREPANCIES' as report_type;
SELECT 
    user_id,
    email,
    recorded_amount,
    actual_approved_amount,
    difference,
    status
FROM purchase_integrity_check
WHERE status != 'OK'
ORDER BY ABS(difference) DESC
LIMIT 10;

-- 4. 2BF53Bユーザーの詳細
SELECT '2BF53B USER DETAIL' as report_type;
SELECT * FROM purchase_integrity_check
WHERE user_id = '2BF53B';

-- 5. 修正が必要なユーザーの一括更新SQL生成
SELECT 'UPDATE STATEMENTS' as report_type;
SELECT 
    'UPDATE users SET total_purchases = ' || actual_approved_amount || 
    ' WHERE user_id = ''' || user_id || '''; -- ' || email || 
    ' (差額: $' || difference || ')' as update_sql
FROM purchase_integrity_check
WHERE status != 'OK' AND ABS(difference) > 1
ORDER BY ABS(difference) DESC;