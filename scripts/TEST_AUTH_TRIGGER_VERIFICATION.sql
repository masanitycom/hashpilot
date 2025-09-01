-- ======================================================
-- HASHPILOT認証トリガーシステム検証・テスト用スクリプト
-- 
-- 目的: 新しく実装した認証トリガーシステムの動作確認
-- 対象: handle_auth_user_registration トリガー
-- 
-- 実行日: 2025-01-24
-- ======================================================

-- ステップ1: システム状態の初期確認
SELECT 
    '=== TRIGGER SYSTEM VERIFICATION ===' as verification_section,
    'Starting comprehensive trigger system verification' as status;

-- ステップ2: トリガー存在確認
SELECT 
    '🔧 TRIGGER EXISTENCE CHECK' as check_type,
    trigger_name,
    event_object_schema,
    event_object_table,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%auth%' 
   OR trigger_name LIKE '%user%registration%'
   OR event_object_table = 'users' AND event_object_schema = 'auth'
ORDER BY trigger_name;

-- ステップ3: 関数存在確認
SELECT 
    '⚙️ FUNCTION EXISTENCE CHECK' as check_type,
    routine_name,
    routine_schema,
    routine_type,
    security_type,
    is_deterministic
FROM information_schema.routines 
WHERE routine_name LIKE '%user%registration%' 
   OR routine_name LIKE '%sync%auth%'
   OR routine_name LIKE '%test%auth%'
ORDER BY routine_name;

-- ステップ4: 組み込み検証関数の実行
SELECT 
    '🧪 BUILT-IN VERIFICATION RESULTS' as test_section,
    test_name,
    status,
    details
FROM public.test_auth_trigger_system();

-- ステップ5: public.usersテーブル構造確認
SELECT 
    '📋 PUBLIC.USERS TABLE STRUCTURE' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE WHEN column_name IN ('referrer_user_id', 'coinw_uid', 'nft_receive_address', 'operation_start_date') 
         THEN '⭐ CRITICAL FOR TRIGGER' 
         ELSE '📦 STANDARD' 
    END as importance
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND table_schema = 'public'
ORDER BY 
    CASE WHEN column_name IN ('referrer_user_id', 'coinw_uid', 'nft_receive_address', 'operation_start_date') 
         THEN 0 
         ELSE 1 
    END,
    ordinal_position;

-- ステップ6: affiliate_cycleテーブル構造確認
SELECT 
    '🔄 AFFILIATE_CYCLE TABLE STRUCTURE' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE WHEN column_name IN ('user_id', 'phase', 'total_nft_count', 'next_action') 
         THEN '⭐ CRITICAL FOR TRIGGER' 
         ELSE '📦 STANDARD' 
    END as importance
FROM information_schema.columns 
WHERE table_name = 'affiliate_cycle' 
  AND table_schema = 'public'
ORDER BY 
    CASE WHEN column_name IN ('user_id', 'phase', 'total_nft_count', 'next_action') 
         THEN 0 
         ELSE 1 
    END,
    ordinal_position;

-- ステップ7: 現在のユーザー同期状況確認
SELECT 
    '👥 USER SYNCHRONIZATION STATUS' as sync_status,
    'Auth users count' as metric,
    COUNT(*) as count
FROM auth.users

UNION ALL

SELECT 
    '👥 USER SYNCHRONIZATION STATUS',
    'Public users count',
    COUNT(*)
FROM public.users

UNION ALL

SELECT 
    '👥 USER SYNCHRONIZATION STATUS',
    'Missing in public.users',
    COUNT(*)
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL

UNION ALL

SELECT 
    '👥 USER SYNCHRONIZATION STATUS',
    'Orphaned in public.users',
    COUNT(*)
FROM public.users pu
LEFT JOIN auth.users au ON pu.id = au.id
WHERE au.id IS NULL;

-- ステップ8: 最近作成されたユーザーの詳細確認
SELECT 
    '🆕 RECENT USER REGISTRATIONS ANALYSIS' as analysis_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    u.has_approved_nft,
    u.operation_start_date,
    u.created_at,
    CASE WHEN ac.user_id IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as affiliate_cycle_status
FROM public.users u
LEFT JOIN public.affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY u.created_at DESC
LIMIT 10;

-- ステップ9: affiliate_cycleの初期化状況確認
SELECT 
    '🔄 AFFILIATE_CYCLE INITIALIZATION STATUS' as init_status,
    ac.user_id,
    ac.phase,
    ac.total_nft_count,
    ac.next_action,
    ac.cycle_number,
    ac.created_at,
    CASE WHEN u.user_id IS NOT NULL THEN '✅ USER EXISTS' ELSE '❌ ORPHANED' END as user_exists
FROM public.affiliate_cycle ac
LEFT JOIN public.users u ON ac.user_id = u.user_id
WHERE ac.created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY ac.created_at DESC
LIMIT 10;

-- ステップ10: 紹介システムの整合性確認
SELECT 
    '🔗 REFERRAL SYSTEM INTEGRITY CHECK' as referral_check,
    'Total users with referrers' as metric,
    COUNT(*) as count
FROM public.users 
WHERE referrer_user_id IS NOT NULL

UNION ALL

SELECT 
    '🔗 REFERRAL SYSTEM INTEGRITY CHECK',
    'Invalid referrer_user_id (referrer not found)',
    COUNT(*)
FROM public.users u
LEFT JOIN public.users r ON u.referrer_user_id = r.user_id
WHERE u.referrer_user_id IS NOT NULL 
  AND r.user_id IS NULL

UNION ALL

SELECT 
    '🔗 REFERRAL SYSTEM INTEGRITY CHECK',
    'Users with CoinW UID set',
    COUNT(*)
FROM public.users 
WHERE coinw_uid IS NOT NULL AND coinw_uid != '';

-- ステップ11: 既存ユーザーの同期が必要かチェック
DO $$
DECLARE
    missing_count INTEGER;
    missing_affiliate_count INTEGER;
BEGIN
    -- public.usersに存在しないauth.usersをカウント
    SELECT COUNT(*) INTO missing_count
    FROM auth.users au
    LEFT JOIN public.users pu ON au.id = pu.id
    WHERE pu.id IS NULL;
    
    -- affiliate_cycleレコードが存在しないpublic.usersをカウント
    SELECT COUNT(*) INTO missing_affiliate_count
    FROM public.users u
    LEFT JOIN public.affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.user_id IS NULL;
    
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'SYNCHRONIZATION REQUIREMENT ANALYSIS';
    RAISE NOTICE '======================================================';
    
    IF missing_count > 0 THEN
        RAISE NOTICE '⚠️  ATTENTION: % auth.users records are missing from public.users', missing_count;
        RAISE NOTICE '📋 RECOMMENDATION: Execute SELECT public.sync_existing_auth_users();';
    ELSE
        RAISE NOTICE '✅ AUTH SYNC: All auth.users are properly synchronized';
    END IF;
    
    IF missing_affiliate_count > 0 THEN
        RAISE NOTICE '⚠️  ATTENTION: % users are missing affiliate_cycle records', missing_affiliate_count;
        RAISE NOTICE '📋 RECOMMENDATION: Review and fix affiliate_cycle initialization';
    ELSE
        RAISE NOTICE '✅ AFFILIATE SYNC: All users have affiliate_cycle records';
    END IF;
    
    RAISE NOTICE '======================================================';
END;
$$;

-- ステップ12: 権限・セキュリティ確認
SELECT 
    '🔒 SECURITY & PERMISSIONS CHECK' as security_check,
    routine_name,
    routine_schema,
    security_type,
    definer_type,
    sql_data_access,
    is_deterministic
FROM information_schema.routines 
WHERE routine_name IN (
    'handle_new_user_registration',
    'sync_existing_auth_users', 
    'test_auth_trigger_system'
)
ORDER BY routine_name;

-- ステップ13: データベースログ確認（過去24時間のトリガー実行ログ）
-- 注意: この部分はSupabaseの設定により利用できない場合があります
SELECT 
    '📊 TRIGGER EXECUTION SUMMARY' as log_summary,
    'Trigger execution logs are available in PostgreSQL logs' as note,
    'Check Supabase dashboard for recent trigger activity' as instruction;

-- ステップ14: 最終ステータス報告
DO $$
BEGIN
    RAISE NOTICE '======================================================';
    RAISE NOTICE '✅ TRIGGER VERIFICATION COMPLETED SUCCESSFULLY';
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Review the above results carefully';
    RAISE NOTICE '2. If any issues found, execute the recommended fixes';
    RAISE NOTICE '3. Test new user registration to verify trigger works';
    RAISE NOTICE '4. Monitor logs during registration process';
    RAISE NOTICE '======================================================';
END;
$$;

-- 完了通知
SELECT 
    '🎯 VERIFICATION COMPLETED' as completion,
    NOW() as completed_at,
    'Review all results above for any issues' as next_action;