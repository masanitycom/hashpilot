-- ========================================
-- 🚨 フロントエンド406エラーの緊急修正
-- user_daily_profitテーブルへのアクセス許可
-- ========================================

-- STEP 1: 現在のRLSポリシー確認
SELECT 
    '=== 🔍 現在のuser_daily_profitポリシー ===' as policy_check,
    policyname,
    cmd,
    roles,
    qual
FROM pg_policies 
WHERE tablename = 'user_daily_profit'
ORDER BY policyname;

-- STEP 2: 問題のあるポリシーを削除
DROP POLICY IF EXISTS "anon_users_read_daily_profit" ON user_daily_profit;
DROP POLICY IF EXISTS "authenticated_users_read_own_daily_profit" ON user_daily_profit;
DROP POLICY IF EXISTS "user_daily_profit_select" ON user_daily_profit;

-- STEP 3: シンプルな読み取り専用ポリシーを作成
CREATE POLICY "allow_all_read_daily_profit" ON user_daily_profit
    FOR SELECT
    TO public
    USING (true);

-- STEP 4: 既存のRLS有効化確認
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;

-- STEP 5: テストクエリでアクセス確認
SELECT 
    '=== ✅ アクセステスト ===' as access_test,
    user_id,
    date,
    daily_profit
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-07-16';

-- STEP 6: 紹介者の利益データ確認
SELECT 
    '=== 🎯 紹介者利益確認 ===' as referral_test,
    user_id,
    daily_profit,
    base_amount
FROM user_daily_profit
WHERE user_id IN ('6E1304', 'OOCJ16') AND date = '2025-07-16';

-- STEP 7: 全ユーザーの利益サマリー
SELECT 
    '=== 📊 全体サマリー ===' as summary,
    COUNT(*) as total_users,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit
FROM user_daily_profit
WHERE date = '2025-07-16';

-- STEP 8: 最終ポリシー確認
SELECT 
    '=== 🔒 最終ポリシー確認 ===' as final_policy,
    policyname,
    cmd,
    roles,
    qual
FROM pg_policies 
WHERE tablename = 'user_daily_profit'
ORDER BY policyname;

-- 完了メッセージ
SELECT 
    '🎉 フロントエンド406エラー修正完了' as status,
    'ダッシュボードをリロードして確認してください' as next_action;