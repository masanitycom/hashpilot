-- ========================================
-- 実際の総売上を確認
-- ========================================

-- 1. 実際の総売上（total_purchases の合計）
SELECT '=== 1. 実際の総売上（total_purchasesの合計） ===' as section;

SELECT
    SUM(total_purchases) as actual_total_sales,
    COUNT(*) as total_users,
    COUNT(*) FILTER (WHERE total_purchases > 0) as users_with_purchases
FROM users;

-- 2. purchasesテーブルの総額（承認済みのみ）
SELECT '=== 2. purchasesテーブルの総額（承認済み） ===' as section;

SELECT
    SUM(amount_usd) as total_approved_purchases,
    COUNT(*) as total_purchase_records,
    COUNT(DISTINCT user_id) as unique_users
FROM purchases
WHERE admin_approved = true;

-- 3. purchasesテーブルの総額（全レコード）
SELECT '=== 3. purchasesテーブルの総額（全レコード） ===' as section;

SELECT
    SUM(amount_usd) as total_all_purchases,
    SUM(amount_usd) FILTER (WHERE admin_approved = true) as approved_amount,
    SUM(amount_usd) FILTER (WHERE admin_approved = false) as pending_amount,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE admin_approved = true) as approved_records,
    COUNT(*) FILTER (WHERE admin_approved = false) as pending_records
FROM purchases;

-- 4. ユーザーごとの購入額とpurchasesの整合性チェック
SELECT '=== 4. total_purchases vs purchases整合性 ===' as section;

WITH user_purchase_sum AS (
    SELECT
        user_id,
        SUM(amount_usd) as purchases_total
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
)
SELECT
    u.user_id,
    u.email,
    u.total_purchases as users_total_purchases,
    ups.purchases_total as purchases_table_sum,
    u.total_purchases - COALESCE(ups.purchases_total, 0) as difference
FROM users u
LEFT JOIN user_purchase_sum ups ON u.user_id = ups.user_id
WHERE u.total_purchases > 0
    AND (u.total_purchases != COALESCE(ups.purchases_total, 0))
ORDER BY ABS(u.total_purchases - COALESCE(ups.purchases_total, 0)) DESC
LIMIT 20;

-- 5. 複数NFT購入者のリスト
SELECT '=== 5. 複数NFT購入者（total_purchases > $1,100） ===' as section;

SELECT
    user_id,
    email,
    full_name,
    total_purchases,
    total_purchases / 1100 as nft_count,
    referrer_user_id
FROM users
WHERE total_purchases > 1100
ORDER BY total_purchases DESC;

-- 6. 管理画面の総売上計算方法を確認
SELECT '=== 6. 管理画面の総売上（どの値を使っているか） ===' as section;

SELECT
    'users.total_purchases合計' as metric,
    TO_CHAR(SUM(total_purchases), 'FM$999,999,999') as value
FROM users
UNION ALL
SELECT
    'purchases承認済み合計',
    TO_CHAR(SUM(amount_usd), 'FM$999,999,999')
FROM purchases
WHERE admin_approved = true
UNION ALL
SELECT
    'purchases全レコード合計',
    TO_CHAR(SUM(amount_usd), 'FM$999,999,999')
FROM purchases;

-- 7. NFT単価が$1,100でない購入があるか確認
SELECT '=== 7. NFT単価が$1,100でない購入 ===' as section;

SELECT
    id,
    user_id,
    nft_quantity,
    amount_usd,
    amount_usd / nft_quantity as price_per_nft,
    admin_approved,
    created_at
FROM purchases
WHERE amount_usd / nft_quantity != 1100
ORDER BY created_at DESC
LIMIT 20;

SELECT '✅ 調査完了' as status;
