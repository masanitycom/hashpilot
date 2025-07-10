-- ユーザー2BF53B (masataka.tak@gmail.com) の$7700 vs $2200差額調査

-- 1. ユーザー基本情報
SELECT 'ユーザー基本情報' as query_type;
SELECT 
    user_id,
    email,
    total_purchases,
    created_at,
    is_active,
    has_approved_nft,
    coinw_uid,
    reward_address_bep20
FROM users 
WHERE user_id = '2BF53B' OR email = 'masataka.tak@gmail.com';

-- 2. 購入履歴（NFT購入額）
SELECT 'NFT購入履歴' as query_type;
SELECT 
    id,
    user_id,
    amount_usd,
    admin_approved,
    payment_status,
    created_at,
    transaction_hash
FROM purchases 
WHERE user_id = '2BF53B'
ORDER BY created_at DESC;

-- 3. 日利履歴（最近30日）
SELECT '日利履歴（最近30日）' as query_type;
SELECT 
    date,
    daily_profit,
    created_at
FROM user_daily_profit 
WHERE user_id = '2BF53B'
ORDER BY date DESC
LIMIT 30;

-- 4. 日利合計
SELECT '日利合計' as query_type;
SELECT 
    COUNT(*) as total_days,
    SUM(daily_profit::DECIMAL) as total_daily_profit,
    AVG(daily_profit::DECIMAL) as avg_daily_profit,
    MIN(daily_profit::DECIMAL) as min_daily_profit,
    MAX(daily_profit::DECIMAL) as max_daily_profit
FROM user_daily_profit 
WHERE user_id = '2BF53B';

-- 5. 月別日利集計
SELECT '月別日利集計' as query_type;
SELECT 
    date_trunc('month', date) as month,
    COUNT(*) as days_count,
    SUM(daily_profit::DECIMAL) as monthly_profit
FROM user_daily_profit 
WHERE user_id = '2BF53B'
GROUP BY date_trunc('month', date)
ORDER BY month DESC;

-- 6. アフィリエイトサイクル情報
SELECT 'アフィリエイトサイクル情報' as query_type;
SELECT 
    user_id,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    created_at,
    updated_at
FROM affiliate_cycle 
WHERE user_id = '2BF53B';

-- 7. 月末出金記録
SELECT '月末出金記録' as query_type;
SELECT 
    withdrawal_month,
    total_amount,
    daily_profit,
    level1_reward,
    level2_reward,
    level3_reward,
    level4_plus_reward,
    status,
    withdrawal_address,
    withdrawal_method,
    created_at
FROM monthly_withdrawals 
WHERE user_id = '2BF53B'
ORDER BY withdrawal_month DESC;

-- 8. 紹介関係（このユーザーが紹介した人）
SELECT '紹介関係（紹介した人）' as query_type;
SELECT 
    user_id,
    email,
    total_purchases,
    created_at
FROM users 
WHERE referrer_user_id = '2BF53B'
ORDER BY created_at DESC;

-- 9. 手動出金申請（もしあれば）
SELECT '手動出金申請' as query_type;
SELECT 
    id,
    user_id,
    withdrawal_amount,
    withdrawal_address,
    status,
    created_at,
    processed_at
FROM withdrawal_requests 
WHERE user_id = '2BF53B'
ORDER BY created_at DESC;

-- 10. 差額計算（推定）
SELECT '差額計算' as query_type;
SELECT 
    '7700 - 日利合計' as calculation,
    7700 - COALESCE(SUM(daily_profit::DECIMAL), 0) as difference
FROM user_daily_profit 
WHERE user_id = '2BF53B';

-- 11. その他のテーブルで2BF53Bのデータ確認
SELECT 'その他テーブル確認' as query_type;
-- reward_transactions テーブルがあれば
SELECT COUNT(*) as reward_transaction_count 
FROM information_schema.tables 
WHERE table_name = 'reward_transactions';

-- 12. 最新の取引
SELECT '最新取引（トランザクション）' as query_type;
SELECT 
    table_name,
    COUNT(*) as record_count
FROM (
    SELECT 'users' as table_name FROM users WHERE user_id = '2BF53B'
    UNION ALL
    SELECT 'purchases' as table_name FROM purchases WHERE user_id = '2BF53B'
    UNION ALL
    SELECT 'user_daily_profit' as table_name FROM user_daily_profit WHERE user_id = '2BF53B'
    UNION ALL
    SELECT 'affiliate_cycle' as table_name FROM affiliate_cycle WHERE user_id = '2BF53B'
    UNION ALL
    SELECT 'monthly_withdrawals' as table_name FROM monthly_withdrawals WHERE user_id = '2BF53B'
) counts
GROUP BY table_name;