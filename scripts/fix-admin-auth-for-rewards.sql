-- 管理者認証の修正と報酬管理用の権限設定

-- 既存の管理者を確認
SELECT email, user_id, created_at FROM admins ORDER BY created_at;

-- 認証ユーザーと管理者テーブルの整合性を確認
SELECT 
    au.email,
    au.id as auth_id,
    a.user_id as admin_user_id,
    au.email_confirmed_at,
    au.last_sign_in_at
FROM auth.users au
LEFT JOIN admins a ON au.email = a.email
WHERE au.email IN (
    'basarasystems@gmail.com',
    'masataka.tak@gmail.com'
)
ORDER BY au.created_at;

-- 管理者テーブルのuser_idを認証IDと同期
UPDATE admins 
SET user_id = (
    SELECT id::text 
    FROM auth.users 
    WHERE auth.users.email = admins.email
)
WHERE user_id != (
    SELECT id::text 
    FROM auth.users 
    WHERE auth.users.email = admins.email
);

-- 管理者権限確認関数を修正
CREATE OR REPLACE FUNCTION is_admin(user_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- メールアドレスで管理者かどうかを確認
    RETURN EXISTS (
        SELECT 1 FROM admins 
        WHERE email = user_email
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 認証IDでも管理者確認できる関数を追加
CREATE OR REPLACE FUNCTION is_admin_by_id(user_auth_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- 認証IDで管理者かどうかを確認
    RETURN EXISTS (
        SELECT 1 FROM admins 
        WHERE user_id = user_auth_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 報酬管理ビューの権限を確認
GRANT SELECT ON admin_monthly_rewards_view TO authenticated;
GRANT SELECT ON user_monthly_rewards TO authenticated;

-- 管理者関数の実行権限を確認
GRANT EXECUTE ON FUNCTION calculate_monthly_rewards TO authenticated;
GRANT EXECUTE ON FUNCTION mark_reward_as_paid TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin_by_id TO authenticated;

-- テスト用の管理者確認
SELECT 
    email,
    is_admin(email) as is_admin_check,
    user_id
FROM admins;
