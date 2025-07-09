-- テスト用管理者の作成（updated_atカラムを使用しない）

DO $$
DECLARE
    v_current_user_email TEXT;
BEGIN
    -- 現在のユーザーのメールアドレスを取得
    SELECT auth.email() INTO v_current_user_email;
    
    RAISE NOTICE '現在のユーザー: %', COALESCE(v_current_user_email, 'NULL');
    
    -- 現在のユーザーを管理者として追加（存在しない場合のみ）
    IF v_current_user_email IS NOT NULL THEN
        INSERT INTO admins (email, is_active, created_at)
        VALUES (v_current_user_email, TRUE, NOW())
        ON CONFLICT (email) DO UPDATE SET
            is_active = TRUE;
        
        RAISE NOTICE '管理者として追加: %', v_current_user_email;
    END IF;
    
    -- テスト用の固定管理者メールアドレスを追加
    INSERT INTO admins (email, is_active, created_at)
    VALUES 
        ('admin@hashpilot.com', TRUE, NOW()),
        ('test@hashpilot.com', TRUE, NOW()),
        ('hashpilot.admin@gmail.com', TRUE, NOW())
    ON CONFLICT (email) DO UPDATE SET
        is_active = TRUE;
    
    RAISE NOTICE 'テスト用管理者を追加しました';
END;
$$;

-- 管理者一覧を表示
SELECT 'Current admins:' as info;
SELECT email, is_active, created_at FROM admins WHERE is_active = TRUE;
