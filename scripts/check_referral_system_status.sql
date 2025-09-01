-- 紹介システムの現状を確認するSQL（読み取り専用）
-- 2025/08/24 - リリース前の最終確認用

-- 1. 紹介関係が設定されているユーザー数を確認
SELECT 
    '紹介関係の設定状況' as check_type,
    COUNT(*) FILTER (WHERE referrer_user_id IS NOT NULL) as has_referrer_count,
    COUNT(*) FILTER (WHERE referrer_user_id IS NULL) as no_referrer_count,
    COUNT(*) as total_users
FROM users;

-- 2. CoinW UIDの保存状況を確認
SELECT 
    'CoinW UID保存状況' as check_type,
    COUNT(*) FILTER (WHERE coinw_uid IS NOT NULL AND coinw_uid != '') as has_coinw_uid,
    COUNT(*) FILTER (WHERE coinw_uid IS NULL OR coinw_uid = '') as no_coinw_uid,
    COUNT(*) as total_users
FROM users;

-- 3. 紹介者が存在するユーザーの詳細（サンプル5件）
SELECT 
    '紹介関係サンプル' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    r.email as referrer_email,
    u.coinw_uid,
    u.created_at
FROM users u
LEFT JOIN users r ON u.referrer_user_id = r.user_id
WHERE u.referrer_user_id IS NOT NULL
LIMIT 5;

-- 4. 最近登録されたユーザーの紹介情報（最新5件）
SELECT 
    '最新登録ユーザー' as check_type,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;

-- 5. auth.usersのメタデータ確認（紹介情報が含まれているか）
SELECT 
    'auth.usersメタデータ' as check_type,
    id,
    email,
    raw_user_meta_data->>'referrer_user_id' as meta_referrer_id,
    raw_user_meta_data->>'coinw_uid' as meta_coinw_uid,
    created_at
FROM auth.users
WHERE raw_user_meta_data IS NOT NULL
  AND (raw_user_meta_data->>'referrer_user_id' IS NOT NULL 
       OR raw_user_meta_data->>'coinw_uid' IS NOT NULL)
LIMIT 5;

-- 6. データベース関数の存在確認
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname LIKE '%user%sync%' 
   OR proname LIKE '%create_user%'
   OR proname LIKE '%handle_new_user%'
LIMIT 10;

-- 7. トリガーの存在確認
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public' 
   OR trigger_schema = 'auth'
ORDER BY event_object_table;

-- 8. 紹介ツリーの深さを確認（実際に機能しているか）
WITH RECURSIVE referral_tree AS (
    -- レベル1: 直接紹介
    SELECT 
        u.user_id,
        u.referrer_user_id,
        1 as level
    FROM users u
    WHERE u.referrer_user_id IS NOT NULL
    
    UNION ALL
    
    -- 再帰的に紹介者を辿る
    SELECT 
        u.user_id,
        u.referrer_user_id,
        rt.level + 1
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level < 20
)
SELECT 
    '紹介ツリー深度' as check_type,
    MAX(level) as max_depth,
    COUNT(DISTINCT user_id) as total_users_in_tree
FROM referral_tree;

-- 9. 投資額の保存状況
SELECT 
    '投資額保存状況' as check_type,
    COUNT(*) FILTER (WHERE total_purchases > 0) as has_investment,
    COUNT(*) FILTER (WHERE total_purchases = 0 OR total_purchases IS NULL) as no_investment,
    SUM(total_purchases) as total_investment_amount
FROM users;

-- 10. affiliate_cycleテーブルとの整合性
SELECT 
    'affiliate_cycle整合性' as check_type,
    COUNT(DISTINCT u.user_id) as users_count,
    COUNT(DISTINCT ac.user_id) as affiliate_cycle_count,
    COUNT(DISTINCT u.user_id) - COUNT(DISTINCT ac.user_id) as missing_in_affiliate_cycle
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id;