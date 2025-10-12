-- メール送信用のRPC関数（修正版）
-- 作成日: 2025年10月11日
-- 修正日: 2025年10月11日

-- 管理者判定用ヘルパー関数（既に存在する場合はスキップ）
CREATE OR REPLACE FUNCTION is_system_admin(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT p_email IN ('basarasystems@gmail.com', 'support@dshsupport.biz');
$$;

-- 1. メール作成＆送信先登録（一斉送信・個別送信）
CREATE OR REPLACE FUNCTION create_system_email(
    p_subject TEXT,
    p_body TEXT,
    p_email_type TEXT, -- 'broadcast' / 'individual'
    p_admin_email TEXT,
    p_target_group TEXT DEFAULT NULL, -- 'all' / 'approved' / 'unapproved'
    p_target_user_ids TEXT[] DEFAULT NULL -- 個別送信の場合のユーザーIDリスト
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email_id UUID;
    v_recipient_count INTEGER := 0;
    v_user_record RECORD;
BEGIN
    -- 管理者権限チェック
    IF NOT is_system_admin(p_admin_email) THEN
        RAISE EXCEPTION '管理者権限がありません';
    END IF;

    -- メール本体レコード作成
    INSERT INTO system_emails (
        subject,
        body,
        email_type,
        sent_by,
        target_group
    ) VALUES (
        p_subject,
        p_body,
        p_email_type,
        p_admin_email,
        p_target_group
    ) RETURNING id INTO v_email_id;

    -- 送信先の登録
    IF p_email_type = 'broadcast' THEN
        -- 一斉送信
        IF p_target_group = 'all' THEN
            -- 全ユーザー
            INSERT INTO email_recipients (email_id, user_id, to_email, status)
            SELECT v_email_id, user_id, email, 'pending'
            FROM users
            WHERE email IS NOT NULL;

        ELSIF p_target_group = 'approved' THEN
            -- 承認済みユーザーのみ
            INSERT INTO email_recipients (email_id, user_id, to_email, status)
            SELECT v_email_id, user_id, email, 'pending'
            FROM users
            WHERE email IS NOT NULL
            AND admin_approved = true;

        ELSIF p_target_group = 'unapproved' THEN
            -- 未承認ユーザーのみ
            INSERT INTO email_recipients (email_id, user_id, to_email, status)
            SELECT v_email_id, user_id, email, 'pending'
            FROM users
            WHERE email IS NOT NULL
            AND (admin_approved = false OR admin_approved IS NULL);
        END IF;

    ELSIF p_email_type = 'individual' THEN
        -- 個別送信
        IF p_target_user_ids IS NULL OR array_length(p_target_user_ids, 1) = 0 THEN
            RAISE EXCEPTION '送信先ユーザーIDが指定されていません';
        END IF;

        INSERT INTO email_recipients (email_id, user_id, to_email, status)
        SELECT v_email_id, user_id, email, 'pending'
        FROM users
        WHERE user_id = ANY(p_target_user_ids)
        AND email IS NOT NULL;
    END IF;

    -- 送信先件数を取得
    SELECT COUNT(*) INTO v_recipient_count
    FROM email_recipients
    WHERE email_id = v_email_id;

    -- システムログに記録
    INSERT INTO system_logs (log_type, operation, message, details)
    VALUES (
        'SUCCESS',
        'create_system_email',
        format('メール作成: %s (%s件)', p_subject, v_recipient_count),
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
        'recipient_count', v_recipient_count,
        'message', format('メールを作成しました（%s件の送信先）', v_recipient_count)
    );

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'メール作成エラー: %', SQLERRM;
END;
$$;

-- 2. ユーザーのメール一覧取得（受信箱）
CREATE OR REPLACE FUNCTION get_user_emails(
    p_user_email TEXT
)
RETURNS TABLE (
    email_id UUID,
    subject TEXT,
    body TEXT,
    from_name TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT;
BEGIN
    -- ユーザーIDを取得
    SELECT user_id INTO v_user_id
    FROM users
    WHERE email = p_user_email;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'ユーザーが見つかりません';
    END IF;

    RETURN QUERY
    SELECT
        se.id as email_id,
        se.subject,
        se.body,
        se.from_name,
        er.status,
        se.created_at,
        er.sent_at,
        er.read_at
    FROM email_recipients er
    INNER JOIN system_emails se ON er.email_id = se.id
    WHERE er.user_id = v_user_id
    ORDER BY se.created_at DESC;
END;
$$;

-- 3. メールを既読にする
CREATE OR REPLACE FUNCTION mark_email_as_read(
    p_email_id UUID,
    p_user_email TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT;
BEGIN
    -- ユーザーIDを取得
    SELECT user_id INTO v_user_id
    FROM users
    WHERE email = p_user_email;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'ユーザーが見つかりません';
    END IF;

    -- メールを既読に更新
    UPDATE email_recipients
    SET status = 'read',
        read_at = NOW()
    WHERE email_id = p_email_id
    AND user_id = v_user_id
    AND status != 'read';

    RETURN json_build_object(
        'success', true,
        'message', 'メールを既読にしました'
    );
END;
$$;

-- 4. 管理者用：メール送信履歴取得
CREATE OR REPLACE FUNCTION get_email_history(
    p_admin_email TEXT,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    email_id UUID,
    subject TEXT,
    email_type TEXT,
    target_group TEXT,
    created_at TIMESTAMPTZ,
    total_recipients INTEGER,
    sent_count INTEGER,
    failed_count INTEGER,
    read_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 管理者権限チェック
    IF NOT is_system_admin(p_admin_email) THEN
        RAISE EXCEPTION '管理者権限がありません';
    END IF;

    RETURN QUERY
    SELECT
        se.id as email_id,
        se.subject,
        se.email_type,
        se.target_group,
        se.created_at,
        COUNT(er.id)::INTEGER as total_recipients,
        COUNT(CASE WHEN er.status = 'sent' THEN 1 END)::INTEGER as sent_count,
        COUNT(CASE WHEN er.status = 'failed' THEN 1 END)::INTEGER as failed_count,
        COUNT(CASE WHEN er.status = 'read' THEN 1 END)::INTEGER as read_count
    FROM system_emails se
    LEFT JOIN email_recipients er ON se.id = er.email_id
    WHERE se.sent_by = p_admin_email
    GROUP BY se.id
    ORDER BY se.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 5. メール配信詳細取得（管理者用）
CREATE OR REPLACE FUNCTION get_email_delivery_details(
    p_email_id UUID,
    p_admin_email TEXT
)
RETURNS TABLE (
    recipient_id UUID,
    user_id TEXT,
    user_email TEXT,
    full_name TEXT,
    status TEXT,
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 管理者権限チェック
    IF NOT is_system_admin(p_admin_email) THEN
        RAISE EXCEPTION '管理者権限がありません';
    END IF;

    RETURN QUERY
    SELECT
        er.id as recipient_id,
        er.user_id,
        er.to_email as user_email,
        u.full_name,
        er.status,
        er.sent_at,
        er.read_at,
        er.error_message
    FROM email_recipients er
    INNER JOIN users u ON er.user_id = u.user_id
    WHERE er.email_id = p_email_id
    ORDER BY er.created_at DESC;
END;
$$;

-- 確認
SELECT '✅ Email RPC functions created successfully' as message;
