-- ========================================
-- 報酬受取りタスクシステムのRLSポリシー修正
-- ========================================

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "admin_manage_questions" ON reward_questions;
DROP POLICY IF EXISTS "users_read_questions" ON reward_questions;
DROP POLICY IF EXISTS "users_own_tasks" ON monthly_reward_tasks;
DROP POLICY IF EXISTS "admin_view_all_tasks" ON monthly_reward_tasks;

-- 管理者のみ設問の作成・編集が可能（is_adminフィールドを使用せずemail直接チェック）
CREATE POLICY "admin_manage_questions" ON reward_questions
    FOR ALL
    TO authenticated
    USING (
        auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
    );

-- 全ユーザーが設問を読み取り可能
CREATE POLICY "users_read_questions" ON reward_questions
    FOR SELECT
    TO authenticated
    USING (is_active = true);

-- ユーザーは自分のタスク状況のみアクセス可能
CREATE POLICY "users_own_tasks" ON monthly_reward_tasks
    FOR ALL
    TO authenticated
    USING (
        user_id = (
            SELECT u.user_id FROM users u 
            WHERE u.email = auth.jwt() ->> 'email'
        )
    );

-- 管理者は全てのタスク状況を閲覧可能
CREATE POLICY "admin_view_all_tasks" ON monthly_reward_tasks
    FOR SELECT
    TO authenticated
    USING (
        auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
    );

SELECT 'Reward task system RLS policies fixed' as status;