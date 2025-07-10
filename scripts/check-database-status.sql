-- データベース状況の確認

-- 1. user_daily_profitテーブルの確認
SELECT 
    'user_daily_profit' as table_name,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    SUM(daily_profit) as total_profit
FROM user_daily_profit;

-- 2. 特定ユーザーの利益データ確認（投資額$1000のユーザー）
SELECT 
    'Sample user profit data' as info,
    u.user_id,
    u.total_purchases,
    COUNT(udp.date) as profit_days,
    SUM(udp.daily_profit) as total_profit,
    AVG(udp.daily_profit) as avg_daily_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.total_purchases >= 1000
GROUP BY u.user_id, u.total_purchases
ORDER BY u.total_purchases DESC
LIMIT 5;

-- 3. affiliate_cycleテーブルの確認
SELECT 
    'affiliate_cycle' as table_name,
    COUNT(*) as total_users,
    SUM(total_nft_count) as total_nfts,
    AVG(total_nft_count) as avg_nft_per_user,
    COUNT(CASE WHEN total_nft_count > 0 THEN 1 END) as users_with_nfts
FROM affiliate_cycle;

-- 4. purchasesテーブルの確認
SELECT 
    'purchases' as table_name,
    COUNT(*) as total_purchases,
    SUM(nft_quantity) as total_nft_purchased,
    SUM(amount_usd::numeric) as total_amount_usd,
    COUNT(CASE WHEN admin_approved = true THEN 1 END) as approved_purchases
FROM purchases;

-- 5. daily_yield_logテーブルの確認
SELECT 
    'daily_yield_log' as table_name,
    COUNT(*) as total_yield_settings,
    MIN(date) as first_yield_date,
    MAX(date) as latest_yield_date,
    AVG(yield_rate * 100) as avg_yield_rate_percent,
    AVG(user_rate * 100) as avg_user_rate_percent
FROM daily_yield_log;

-- 6. データ整合性チェック：ユーザーのNFT数の比較
SELECT 
    'NFT count comparison' as check_type,
    u.user_id,
    u.total_purchases,
    FLOOR(u.total_purchases / 1100) as calculated_nft_from_purchases,
    ac.total_nft_count as affiliate_cycle_nft_count,
    COALESCE(SUM(p.nft_quantity), 0) as purchases_nft_total
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.total_purchases > 0
GROUP BY u.user_id, u.total_purchases, ac.total_nft_count
ORDER BY u.total_purchases DESC
LIMIT 10;

-- 7. 昨日の日付でのデータ確認
SELECT 
    'Yesterday data check' as info,
    CURRENT_DATE - INTERVAL '1 day' as yesterday,
    COUNT(*) as users_with_yesterday_profit
FROM user_daily_profit 
WHERE date = CURRENT_DATE - INTERVAL '1 day';

-- 8. 運用開始日の確認（購入日の翌日から運用開始になっているか）
SELECT 
    'Purchase vs profit start date check' as check_type,
    p.user_id,
    p.purchase_date,
    p.purchase_date + INTERVAL '1 day' as expected_profit_start,
    MIN(udp.date) as actual_first_profit_date,
    CASE 
        WHEN MIN(udp.date) = p.purchase_date + INTERVAL '1 day' THEN 'CORRECT'
        ELSE 'MISMATCH'
    END as timing_check
FROM purchases p
LEFT JOIN user_daily_profit udp ON p.user_id = udp.user_id
WHERE p.admin_approved = true
GROUP BY p.user_id, p.purchase_date
ORDER BY p.purchase_date DESC
LIMIT 5;