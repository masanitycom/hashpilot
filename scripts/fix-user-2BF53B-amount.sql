-- ユーザー2BF53Bのtotal_purchasesを修正

-- 1. 現在の状態を確認
SELECT 'BEFORE UPDATE' as status;
SELECT 
    user_id,
    email,
    total_purchases,
    created_at
FROM users 
WHERE user_id = '2BF53B';

-- 2. 実際の購入履歴を確認（transaction_hash列を除外）
SELECT 'PURCHASE HISTORY' as status;
SELECT 
    id,
    user_id,
    amount_usd,
    nft_quantity,
    admin_approved,
    payment_status,
    created_at
FROM purchases 
WHERE user_id = '2BF53B'
ORDER BY created_at DESC;

-- 3. 承認済み購入の合計を計算
SELECT 'APPROVED PURCHASES TOTAL' as status;
SELECT 
    COUNT(*) as total_purchases,
    SUM(amount_usd) as total_amount,
    SUM(nft_quantity) as total_nfts
FROM purchases 
WHERE user_id = '2BF53B' 
AND admin_approved = true;

-- 4. total_purchasesを正しい値に更新
-- 管理画面で$2200と表示されているので、それに合わせる
UPDATE users 
SET total_purchases = 2200
WHERE user_id = '2BF53B';

-- 5. 更新後の確認
SELECT 'AFTER UPDATE' as status;
SELECT 
    user_id,
    email,
    total_purchases,
    updated_at
FROM users 
WHERE user_id = '2BF53B';

-- 6. アフィリエイトサイクル情報も確認
SELECT 'AFFILIATE CYCLE' as status;
SELECT 
    user_id,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count
FROM affiliate_cycle 
WHERE user_id = '2BF53B';

-- 7. 日利合計も確認
SELECT 'DAILY PROFIT SUMMARY' as status;
SELECT 
    COUNT(*) as total_days,
    SUM(daily_profit::DECIMAL) as total_profit,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit 
WHERE user_id = '2BF53B';

-- 8. 差額の原因を調査
SELECT 'AMOUNT ANALYSIS' as status;
WITH user_amounts AS (
    SELECT 
        u.user_id,
        u.total_purchases as users_table_amount,
        COALESCE(p.approved_total, 0) as actual_approved_purchases,
        COALESCE(ac.cum_usdt, 0) as cycle_cum_usdt,
        COALESCE(ac.available_usdt, 0) as cycle_available_usdt,
        COALESCE(dp.total_profit, 0) as total_daily_profit
    FROM users u
    LEFT JOIN (
        SELECT 
            user_id,
            SUM(amount_usd) as approved_total
        FROM purchases
        WHERE admin_approved = true
        GROUP BY user_id
    ) p ON u.user_id = p.user_id
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    LEFT JOIN (
        SELECT 
            user_id,
            SUM(daily_profit::DECIMAL) as total_profit
        FROM user_daily_profit
        GROUP BY user_id
    ) dp ON u.user_id = dp.user_id
    WHERE u.user_id = '2BF53B'
)
SELECT 
    *,
    users_table_amount - actual_approved_purchases as difference,
    actual_approved_purchases + cycle_cum_usdt + cycle_available_usdt + total_daily_profit as grand_total
FROM user_amounts;