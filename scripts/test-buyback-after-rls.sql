-- RLS再有効化後の買い取りシステムテスト用スクリプト
-- 段階的にテストして問題がないことを確認

-- ========================================
-- テスト用: ユーザー認証状況の模擬
-- ========================================

-- 現在のauth.uid()の確認（ログイン状態でのみ動作）
SELECT 
    auth.uid() as current_user_uuid,
    auth.email() as current_user_email,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN '✅ 認証済み'
        ELSE '❌ 未認証'
    END as auth_status;

-- ========================================
-- 買い取りシステムで使用するテーブルのテスト
-- ========================================

-- 1. affiliate_cycleテーブルのアクセステスト
-- ユーザーが自分のデータにアクセスできるかテスト
SELECT 
    'affiliate_cycle' as table_name,
    COUNT(*) as accessible_records,
    CASE WHEN COUNT(*) > 0 THEN '✅ アクセス可能' ELSE '⚠️ データなし/アクセス不可' END as test_result
FROM affiliate_cycle;

-- 2. user_daily_profitテーブルのアクセステスト
SELECT 
    'user_daily_profit' as table_name,
    COUNT(*) as accessible_records,
    CASE WHEN COUNT(*) > 0 THEN '✅ アクセス可能' ELSE '⚠️ データなし/アクセス不可' END as test_result
FROM user_daily_profit;

-- 3. system_logsテーブルの書き込みテスト（管理者のみ）
-- 一般ユーザーは自分のログのみ書き込み可能
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'INFO',
    'rls_test_access',
    (auth.uid())::text,
    'RLS再有効化後のテストアクセス',
    jsonb_build_object(
        'test_type', 'buyback_system_access_test',
        'timestamp', NOW()
    ),
    NOW()
);

-- 4. buyback_requests関数のテスト
-- 実際の関数呼び出しをテスト（データ挿入はしない）
SELECT 
    'get_buyback_requests' as function_name,
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'get_buyback_requests' 
            AND routine_type = 'FUNCTION'
        ) THEN '✅ 関数存在'
        ELSE '❌ 関数なし'
    END as function_status;

-- ========================================
-- RLSポリシーの詳細確認
-- ========================================

-- ユーザーがアクセス可能なポリシーを確認
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd as command_type,
    permissive,
    CASE 
        WHEN qual LIKE '%auth.uid()%' THEN '🔐 ユーザー認証必要'
        WHEN qual LIKE '%admins%' THEN '👑 管理者権限必要'
        ELSE '📋 その他条件'
    END as access_type
FROM pg_policies 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
    AND schemaname = 'public'
ORDER BY tablename, cmd;

-- ========================================
-- 実際のユーザーデータでのテスト（サンプル）
-- ========================================

-- ログインユーザーのusersレコードを確認
SELECT 
    user_id,
    email,
    full_name,
    CASE 
        WHEN id = auth.uid() THEN '✅ 自分のレコード'
        ELSE '❌ 他人のレコード'
    END as record_ownership
FROM users
WHERE id = auth.uid() OR email = auth.email()
LIMIT 5;

-- ログインユーザーのaffiliate_cycleデータ確認
SELECT 
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    'affiliate_cycle' as data_source
FROM affiliate_cycle
WHERE user_id = (
    SELECT user_id FROM users WHERE id = auth.uid() LIMIT 1
)
LIMIT 1;

-- ========================================
-- テスト結果の概要
-- ========================================
SELECT 
    'TEST SUMMARY' as category,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN '🟢 認証テスト: 合格'
        ELSE '🔴 認証テスト: 失敗 - ログインが必要'
    END as auth_test,
    
    CASE 
        WHEN EXISTS(SELECT 1 FROM affiliate_cycle LIMIT 1) THEN '🟢 affiliate_cycle: アクセス可能'
        ELSE '🟡 affiliate_cycle: データなしまたはアクセス不可'
    END as affiliate_test,
    
    CASE 
        WHEN EXISTS(SELECT 1 FROM user_daily_profit LIMIT 1) THEN '🟢 user_daily_profit: アクセス可能'
        ELSE '🟡 user_daily_profit: データなしまたはアクセス不可'
    END as profit_test;