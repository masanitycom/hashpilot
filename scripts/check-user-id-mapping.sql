-- ユーザーIDマッピングの確認

-- 1. 認証IDとユーザーIDの関係を確認
SELECT 
    'User mapping check' as info,
    id as auth_id,
    user_id,
    email,
    total_purchases
FROM users
WHERE user_id IN ('7A9637', 'b5e6e7')
OR id = '7241f7f8-d05f-4c62-ac32-c2f8d8a93323';

-- 2. user_daily_profitのデータ存在確認
SELECT 
    'Daily profit data' as info,
    user_id,
    COUNT(*) as record_count,
    MAX(date) as latest_date
FROM user_daily_profit
WHERE user_id IN ('7A9637', 'b5e6e7', '7241f7f8-d05f-4c62-ac32-c2f8d8a93323')
GROUP BY user_id;

-- 3. 認証IDでuser_daily_profitにデータがあるか確認
SELECT 
    'Check by auth ID' as info,
    user_id,
    date,
    daily_profit
FROM user_daily_profit
WHERE user_id = '7241f7f8-d05f-4c62-ac32-c2f8d8a93323'
ORDER BY date DESC
LIMIT 5;

-- 4. RLSポリシーの詳細確認
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename IN ('user_daily_profit', 'affiliate_cycle', 'users')
ORDER BY tablename, policyname;