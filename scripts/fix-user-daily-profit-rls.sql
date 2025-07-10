-- user_daily_profitテーブルのRLSポリシーを修正

-- 1. 現在のRLS状態を確認
SELECT 
    'RLS status' as info,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'user_daily_profit';

-- 2. 現在のポリシーを確認
SELECT 
    'Current policies' as info,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'user_daily_profit';

-- 3. RLSを有効化（まだの場合）
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;

-- 4. 既存のポリシーを削除（あれば）
DROP POLICY IF EXISTS "Users can view own profit data" ON user_daily_profit;
DROP POLICY IF EXISTS "Allow users to view their own profit data" ON user_daily_profit;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON user_daily_profit;

-- 5. 新しいポリシーを作成
-- ユーザーは自分のデータを閲覧できる
CREATE POLICY "Users can view own profit data" ON user_daily_profit
FOR SELECT
TO authenticated
USING (
    -- usersテーブルのidとuser_idの関係を考慮
    user_id IN (
        SELECT user_id 
        FROM users 
        WHERE id = auth.uid()
    )
);

-- 6. 管理者は全データを閲覧できる
CREATE POLICY "Admins can view all profit data" ON user_daily_profit
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM admins 
        WHERE email = auth.jwt()->>'email' 
        AND is_active = true
    )
);

-- 7. 動作確認用のテストクエリ
-- masataka.takユーザー（user_id: 2BF53B）のデータ存在確認
SELECT 
    'Test data for 2BF53B' as info,
    user_id,
    date,
    daily_profit,
    base_amount
FROM user_daily_profit 
WHERE user_id = '2BF53B' 
AND date = '2025-07-09';

-- 8. usersテーブルとの結合確認
SELECT 
    'User to profit mapping' as info,
    u.id as auth_id,
    u.user_id,
    u.email,
    udp.date,
    udp.daily_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.email = 'masataka.tak@gmail.com'
AND udp.date = '2025-07-09';