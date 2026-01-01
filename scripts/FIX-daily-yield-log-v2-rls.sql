-- ========================================
-- daily_yield_log_v2 テーブルのRLSポリシー修正
-- ========================================
-- 問題: 管理者でもフロントエンドからデータが取得できない
-- 原因: RLSポリシーが設定されていないか、適切でない
-- ========================================

-- 1. 現在のRLSポリシーを確認
SELECT '=== 1. 現在のRLSポリシー確認 ===' as section;
SELECT
    policyname,
    permissive,
    roles,
    cmd,
    qual::text as condition
FROM pg_policies
WHERE tablename = 'daily_yield_log_v2';

-- 2. RLSが有効か確認
SELECT '=== 2. RLS状態確認 ===' as section;
SELECT
    relname as table_name,
    relrowsecurity as rls_enabled
FROM pg_class
WHERE relname = 'daily_yield_log_v2';

-- ========================================
-- 3. RLSポリシーを修正
-- ========================================

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "daily_yield_log_v2_select_policy" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "daily_yield_log_v2_insert_policy" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "daily_yield_log_v2_update_policy" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "daily_yield_log_v2_delete_policy" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "Allow authenticated read" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "Allow admin insert" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "Allow admin update" ON daily_yield_log_v2;
DROP POLICY IF EXISTS "Allow admin delete" ON daily_yield_log_v2;

-- RLSを有効化（まだ有効でない場合）
ALTER TABLE daily_yield_log_v2 ENABLE ROW LEVEL SECURITY;

-- SELECTポリシー: 認証済みユーザーは全て読み取り可能
CREATE POLICY "daily_yield_log_v2_select_all"
ON daily_yield_log_v2
FOR SELECT
TO authenticated
USING (true);

-- INSERTポリシー: 管理者のみ挿入可能
CREATE POLICY "daily_yield_log_v2_insert_admin"
ON daily_yield_log_v2
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM users
        WHERE email = auth.jwt() ->> 'email'
        AND is_admin = true
    )
    OR auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
);

-- UPDATEポリシー: 管理者のみ更新可能
CREATE POLICY "daily_yield_log_v2_update_admin"
ON daily_yield_log_v2
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM users
        WHERE email = auth.jwt() ->> 'email'
        AND is_admin = true
    )
    OR auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
);

-- DELETEポリシー: 管理者のみ削除可能
CREATE POLICY "daily_yield_log_v2_delete_admin"
ON daily_yield_log_v2
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM users
        WHERE email = auth.jwt() ->> 'email'
        AND is_admin = true
    )
    OR auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
);

-- ========================================
-- 4. 修正後のRLSポリシーを確認
-- ========================================
SELECT '=== 4. 修正後のRLSポリシー ===' as section;
SELECT
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'daily_yield_log_v2';

SELECT '✅ RLSポリシー修正完了' as result;
