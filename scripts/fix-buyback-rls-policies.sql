/* buyback_requests テーブルのRLSポリシーを修正 */

/* 既存のポリシーを削除 */
DROP POLICY IF EXISTS "Users can view their own buyback requests" ON buyback_requests;
DROP POLICY IF EXISTS "Users can create their own buyback requests" ON buyback_requests;
DROP POLICY IF EXISTS "Users can update their own buyback requests" ON buyback_requests;
DROP POLICY IF EXISTS "Admins can view all buyback requests" ON buyback_requests;
DROP POLICY IF EXISTS "Admins can update all buyback requests" ON buyback_requests;

/* ユーザーが自分の買い取り申請を閲覧できるポリシー */
CREATE POLICY "Users can view their own buyback requests" ON buyback_requests
    FOR SELECT USING (user_id = auth.uid()::text);

/* ユーザーが自分の買い取り申請を作成できるポリシー */
CREATE POLICY "Users can create their own buyback requests" ON buyback_requests
    FOR INSERT WITH CHECK (user_id = auth.uid()::text);

/* ユーザーが自分の買い取り申請を更新できるポリシー（キャンセル用） */
CREATE POLICY "Users can update their own buyback requests" ON buyback_requests
    FOR UPDATE USING (user_id = auth.uid()::text);

/* 管理者が全ての買い取り申請を閲覧できるポリシー */
CREATE POLICY "Admins can view all buyback requests" ON buyback_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
        OR
        auth.email() IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com')
    );

/* 管理者が全ての買い取り申請を更新できるポリシー */
CREATE POLICY "Admins can update all buyback requests" ON buyback_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
        OR
        auth.email() IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com')
    );

/* affiliate_cycle テーブルのポリシーも確認・修正 */
DROP POLICY IF EXISTS "Users can view their own affiliate cycle" ON affiliate_cycle;
DROP POLICY IF EXISTS "Users can update their own affiliate cycle" ON affiliate_cycle;
DROP POLICY IF EXISTS "Admins can view all affiliate cycles" ON affiliate_cycle;

CREATE POLICY "Users can view their own affiliate cycle" ON affiliate_cycle
    FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY "Users can update their own affiliate cycle" ON affiliate_cycle
    FOR UPDATE USING (user_id = auth.uid()::text);

CREATE POLICY "Admins can view all affiliate cycles" ON affiliate_cycle
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
        OR
        auth.email() IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com')
    );

/* user_daily_profit テーブルのポリシーも確認・修正 */
DROP POLICY IF EXISTS "Users can view their own daily profit" ON user_daily_profit;
DROP POLICY IF EXISTS "Admins can view all daily profits" ON user_daily_profit;

CREATE POLICY "Users can view their own daily profit" ON user_daily_profit
    FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY "Admins can view all daily profits" ON user_daily_profit
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
        OR
        auth.email() IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com')
    );

/* system_logs テーブルのポリシー（ユーザーが自分のログを追加できるように） */
DROP POLICY IF EXISTS "Users can insert their own logs" ON system_logs;
DROP POLICY IF EXISTS "Admins can view all logs" ON system_logs;

CREATE POLICY "Users can insert their own logs" ON system_logs
    FOR INSERT WITH CHECK (user_id = auth.uid()::text OR user_id IS NULL);

CREATE POLICY "Admins can view all logs" ON system_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
        OR
        auth.email() IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com')
    );

/* 権限確認用のヘルパー関数を作成 */
CREATE OR REPLACE FUNCTION is_user_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM admins 
        WHERE user_id = auth.uid()::text
    )
    OR
    auth.email() IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com');
$$;