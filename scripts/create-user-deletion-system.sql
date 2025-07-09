-- ユーザー完全削除システムの構築

-- 1. 削除ログテーブルの作成
CREATE TABLE IF NOT EXISTS user_deletion_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    deleted_user_id TEXT NOT NULL,
    deleted_email TEXT NOT NULL,
    admin_email TEXT NOT NULL,
    deletion_reason TEXT,
    deleted_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. ユーザー削除情報取得関数
CREATE OR REPLACE FUNCTION get_user_deletion_info(target_user_id TEXT)
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    total_purchases NUMERIC,
    purchase_count BIGINT,
    referral_count BIGINT,
    referred_by_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.email,
        COALESCE(u.total_purchases, 0) as total_purchases,
        COALESCE(purchase_stats.purchase_count, 0) as purchase_count,
        COALESCE(referral_stats.referral_count, 0) as referral_count,
        CASE WHEN u.referrer_user_id IS NOT NULL THEN 1 ELSE 0 END::BIGINT as referred_by_count
    FROM users u
    LEFT JOIN (
        SELECT 
            user_id,
            COUNT(*) as purchase_count
        FROM purchases 
        WHERE user_id = target_user_id
        GROUP BY user_id
    ) purchase_stats ON u.user_id = purchase_stats.user_id
    LEFT JOIN (
        SELECT 
            referrer_user_id,
            COUNT(*) as referral_count
        FROM users 
        WHERE referrer_user_id = target_user_id
        GROUP BY referrer_user_id
    ) referral_stats ON u.user_id = referral_stats.referrer_user_id
    WHERE u.user_id = target_user_id;
END;
$$;

-- 3. ユーザー完全削除関数
CREATE OR REPLACE FUNCTION delete_user_completely(
    target_user_id TEXT,
    admin_email TEXT,
    deletion_reason TEXT DEFAULT 'Admin deletion'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_record RECORD;
    auth_user_id UUID;
    deleted_data JSONB;
BEGIN
    -- 管理者権限チェック
    IF NOT is_admin(admin_email) THEN
        RAISE EXCEPTION 'Admin privileges required';
    END IF;

    -- ユーザー情報取得
    SELECT * INTO user_record FROM users WHERE user_id = target_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', target_user_id;
    END IF;

    -- auth.usersからuser_idを取得
    SELECT id INTO auth_user_id 
    FROM auth.users 
    WHERE email = user_record.email;

    -- 削除データの記録準備
    SELECT jsonb_build_object(
        'user_data', row_to_json(user_record),
        'purchases', (
            SELECT jsonb_agg(row_to_json(p)) 
            FROM purchases p 
            WHERE p.user_id = target_user_id
        ),
        'referrals', (
            SELECT jsonb_agg(row_to_json(r)) 
            FROM users r 
            WHERE r.referrer_user_id = target_user_id
        )
    ) INTO deleted_data;

    -- 関連データの削除（順序重要）
    
    -- 1. 紹介関係の更新（このユーザーを紹介者とする他のユーザー）
    UPDATE users 
    SET referrer_user_id = NULL 
    WHERE referrer_user_id = target_user_id;

    -- 2. 購入記録の削除
    DELETE FROM purchases WHERE user_id = target_user_id;

    -- 3. ユーザーレコードの削除
    DELETE FROM users WHERE user_id = target_user_id;

    -- 4. Supabase Authからの削除（存在する場合）
    IF auth_user_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = auth_user_id;
    END IF;

    -- 5. 削除ログの記録
    INSERT INTO user_deletion_logs (
        deleted_user_id,
        deleted_email,
        admin_email,
        deletion_reason,
        deleted_data
    ) VALUES (
        target_user_id,
        user_record.email,
        admin_email,
        deletion_reason,
        deleted_data
    );

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to delete user: %', SQLERRM;
END;
$$;

-- 4. 削除ログ確認関数
CREATE OR REPLACE FUNCTION get_deletion_logs(limit_count INTEGER DEFAULT 50)
RETURNS TABLE (
    id UUID,
    deleted_user_id TEXT,
    deleted_email TEXT,
    admin_email TEXT,
    deletion_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dl.id,
        dl.deleted_user_id,
        dl.deleted_email,
        dl.admin_email,
        dl.deletion_reason,
        dl.created_at
    FROM user_deletion_logs dl
    ORDER BY dl.created_at DESC
    LIMIT limit_count;
END;
$$;

-- 5. RLSポリシーの設定
ALTER TABLE user_deletion_logs ENABLE ROW LEVEL SECURITY;

-- 管理者のみアクセス可能
CREATE POLICY "Admin only access to deletion logs" ON user_deletion_logs
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE email = auth.jwt() ->> 'email'
        )
    );

-- 6. 権限設定
GRANT EXECUTE ON FUNCTION get_user_deletion_info(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_completely(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_deletion_logs(INTEGER) TO authenticated;

-- 完了メッセージ
SELECT 'User deletion system created successfully' as status;
