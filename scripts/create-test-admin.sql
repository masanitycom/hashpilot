-- テスト用管理者を作成

-- 現在のユーザーを管理者として追加
DO $$
DECLARE
    v_current_email TEXT;
BEGIN
    -- 現在のユーザーのメールアドレスを取得
    SELECT auth.email() INTO v_current_email;
    
    IF v_current_email IS NOT NULL THEN
        -- adminsテーブルが存在する場合のみ実行
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admins') THEN
            -- 既存の管理者レコードを確認
            IF NOT EXISTS (SELECT 1 FROM admins WHERE email = v_current_email) THEN
                INSERT INTO admins (email, is_active, created_at)
                VALUES (v_current_email, TRUE, NOW());
                RAISE NOTICE 'Added admin: %', v_current_email;
            ELSE
                -- 既存レコードをアクティブに更新
                UPDATE admins 
                SET is_active = TRUE, updated_at = NOW()
                WHERE email = v_current_email;
                RAISE NOTICE 'Updated admin: %', v_current_email;
            END IF;
        END IF;
    ELSE
        RAISE NOTICE 'No authenticated user found';
    END IF;
END;
$$;

-- テスト用の固定管理者も追加
INSERT INTO admins (email, is_active, created_at)
VALUES 
    ('admin@hashpilot.com', TRUE, NOW()),
    ('test@hashpilot.com', TRUE, NOW()),
    ('hashpilot.admin@gmail.com', TRUE, NOW())
ON CONFLICT (email) DO UPDATE SET
    is_active = TRUE,
    updated_at = NOW();
