-- Y9FVT1ユーザーのデバッグ情報を取得

-- torucajino@gmail.com のユーザー情報を完全確認
SELECT 
    '=== torucajino@gmail.com のユーザー情報 ===' as debug_info,
    id as supabase_auth_id,
    user_id as custom_user_id,
    email,
    full_name,
    coinw_uid,
    total_purchases,
    created_at,
    is_active,
    has_approved_nft
FROM users 
WHERE email = 'torucajino@gmail.com';

-- 同じメールアドレスで複数レコードがないか確認
SELECT 
    '=== 重複チェック ===' as debug_info,
    COUNT(*) as record_count,
    'torucajino@gmail.com' as email
FROM users 
WHERE email = 'torucajino@gmail.com';

-- Y9FVT1の利益記録を再確認
SELECT 
    '=== Y9FVT1の利益記録 ===' as debug_info,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase
FROM user_daily_profit 
WHERE user_id = 'Y9FVT1'
ORDER BY date;

-- 購入記録とuser_idの整合性確認
SELECT 
    '=== 購入記録の整合性 ===' as debug_info,
    p.user_id as purchase_user_id,
    u.user_id as users_user_id,
    u.email,
    p.amount_usd,
    p.admin_approved,
    p.admin_approved_at
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE u.email = 'torucajino@gmail.com' OR p.user_id = 'Y9FVT1';