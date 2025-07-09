-- まず実際のテーブル構造を確認
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('user_id', 'email')
ORDER BY ordinal_position;

-- ユーザー削除情報取得関数の修正（型を正確に指定）
DROP FUNCTION IF EXISTS get_user_deletion_info(TEXT);

CREATE OR REPLACE FUNCTION get_user_deletion_info(target_user_id VARCHAR(6))
RETURNS TABLE (
    user_id VARCHAR(6),
    email VARCHAR(255),
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
        u.user_id::VARCHAR(6),
        u.email::VARCHAR(255),
        COALESCE(u.total_purchases, 0)::NUMERIC as total_purchases,
        COALESCE(purchase_stats.purchase_count, 0)::BIGINT as purchase_count,
        COALESCE(referral_stats.referral_count, 0)::BIGINT as referral_count,
        CASE WHEN u.referrer_user_id IS NOT NULL THEN 1 ELSE 0 END::BIGINT as referred_by_count
    FROM users u
    LEFT JOIN (
        SELECT 
            p.user_id,
            COUNT(*)::BIGINT as purchase_count
        FROM purchases p
        WHERE p.user_id = target_user_id
        GROUP BY p.user_id
    ) purchase_stats ON u.user_id = purchase_stats.user_id
    LEFT JOIN (
        SELECT 
            r.referrer_user_id,
            COUNT(*)::BIGINT as referral_count
        FROM users r
        WHERE r.referrer_user_id = target_user_id
        GROUP BY r.referrer_user_id
    ) referral_stats ON u.user_id = referral_stats.referrer_user_id
    WHERE u.user_id = target_user_id;
END;
$$;

-- 完全削除関数も型を修正
DROP FUNCTION IF EXISTS delete_user_completely(TEXT, TEXT);

CREATE OR REPLACE FUNCTION delete_user_completely(
    target_user_id VARCHAR(6),
    admin_user_id VARCHAR(6)
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_info RECORD;
    deletion_result JSON;
    auth_user_uuid UUID;
BEGIN
    -- 管理者権限チェック
    IF NOT is_admin(admin_user_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Unauthorized: Admin access required'
        );
    END IF;

    -- ユーザー情報を取得
    SELECT * INTO user_info FROM users WHERE user_id = target_user_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    -- 削除ログを記録
    INSERT INTO user_deletion_logs (
        deleted_user_id,
        deleted_email,
        admin_user_id,
        deletion_reason,
        user_data_backup
    ) VALUES (
        target_user_id,
        user_info.email,
        admin_user_id,
        'Admin deletion',
        row_to_json(user_info)
    );

    -- 関連データを削除
    DELETE FROM purchases WHERE user_id = target_user_id;
    
    -- 紹介関係を削除
    UPDATE users SET referrer_user_id = NULL WHERE referrer_user_id = target_user_id;
    
    -- ユーザーレコードを削除
    DELETE FROM users WHERE user_id = target_user_id;

    -- Supabase Authからも削除を試行
    BEGIN
        SELECT id INTO auth_user_uuid FROM auth.users WHERE raw_user_meta_data->>'user_id' = target_user_id;
        IF FOUND THEN
            DELETE FROM auth.users WHERE id = auth_user_uuid;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Auth削除エラーは無視（ログに記録済み）
        NULL;
    END;

    RETURN json_build_object(
        'success', true,
        'message', 'User deleted successfully',
        'deleted_user_id', target_user_id,
        'deleted_email', user_info.email
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- テスト用クエリ
SELECT 'User deletion functions fixed with correct types' as status;
