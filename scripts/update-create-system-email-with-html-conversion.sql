-- ========================================
-- create_system_email関数にHTML自動変換を追加
-- ========================================

CREATE OR REPLACE FUNCTION create_system_email(
    p_subject TEXT,
    p_body TEXT,
    p_email_type TEXT DEFAULT 'broadcast',
    p_admin_email TEXT DEFAULT NULL,
    p_target_group TEXT DEFAULT 'all',
    p_target_user_ids TEXT[] DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email_id UUID;
    v_recipient_count INTEGER := 0;
    v_user_record RECORD;
    v_html_body TEXT;
BEGIN
    -- 管理者権限チェック
    IF p_admin_email IS NULL OR (
        p_admin_email != 'basarasystems@gmail.com' AND
        p_admin_email != 'support@dshsupport.biz'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required';
    END IF;

    -- ⭐ プレーンテキストを自動的にHTMLに変換
    v_html_body := text_to_html(p_body);

    -- システムメールレコードを作成
    INSERT INTO system_emails (
        subject,
        body,
        email_type,
        from_name,
        from_email,
        sent_by,
        target_group,
        created_at
    )
    VALUES (
        p_subject,
        v_html_body,  -- ⭐ 変換後のHTMLを保存
        p_email_type,
        'HASHPILOT',
        'noreply@hashpilot.biz',
        p_admin_email,
        p_target_group,
        NOW()
    )
    RETURNING id INTO v_email_id;

    -- 送信先ユーザーを登録
    IF p_email_type = 'broadcast' THEN
        -- 一斉送信
        IF p_target_group = 'all' THEN
            -- 全ユーザー
            FOR v_user_record IN
                SELECT user_id, email FROM users WHERE email IS NOT NULL
            LOOP
                INSERT INTO email_recipients (email_id, user_id, to_email, status)
                VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
                v_recipient_count := v_recipient_count + 1;
            END LOOP;

        ELSIF p_target_group = 'approved' THEN
            -- 承認済みユーザーのみ
            FOR v_user_record IN
                SELECT user_id, email FROM users WHERE email IS NOT NULL AND has_approved_nft = true
            LOOP
                INSERT INTO email_recipients (email_id, user_id, to_email, status)
                VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
                v_recipient_count := v_recipient_count + 1;
            END LOOP;

        ELSIF p_target_group = 'unapproved' THEN
            -- 未承認ユーザーのみ
            FOR v_user_record IN
                SELECT user_id, email FROM users WHERE email IS NOT NULL AND has_approved_nft = false
            LOOP
                INSERT INTO email_recipients (email_id, user_id, to_email, status)
                VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
                v_recipient_count := v_recipient_count + 1;
            END LOOP;
        END IF;

    ELSIF p_email_type = 'individual' THEN
        -- 個別送信
        IF p_target_user_ids IS NOT NULL AND array_length(p_target_user_ids, 1) > 0 THEN
            FOR v_user_record IN
                SELECT user_id, email FROM users WHERE user_id = ANY(p_target_user_ids) AND email IS NOT NULL
            LOOP
                INSERT INTO email_recipients (email_id, user_id, to_email, status)
                VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
                v_recipient_count := v_recipient_count + 1;
            END LOOP;
        END IF;
    END IF;

    -- システムログに記録
    INSERT INTO system_logs (log_type, operation, message, details)
    VALUES (
        'SUCCESS',
        'create_system_email',
        format('システムメールを作成しました: %s (%s件)', p_subject, v_recipient_count),
        jsonb_build_object(
            'email_id', v_email_id,
            'email_type', p_email_type,
            'target_group', p_target_group,
            'recipient_count', v_recipient_count,
            'admin_email', p_admin_email
        )
    );

    RETURN json_build_object(
        'success', true,
        'email_id', v_email_id,
        'recipient_count', v_recipient_count
    );

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating system email: %', SQLERRM;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION create_system_email(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[]) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ create_system_email関数を更新しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更内容:';
    RAISE NOTICE '  - text_to_html()関数を呼び出して自動変換';
    RAISE NOTICE '  - 改行が<br>に変換される';
    RAISE NOTICE '  - URLが自動的にリンク化される';
    RAISE NOTICE '  - HTMLを書かなくても見やすいメールが送信できる';
    RAISE NOTICE '===========================================';
END $$;
