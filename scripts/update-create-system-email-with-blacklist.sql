-- ========================================
-- create_system_email関数を更新
-- メール送信除外リスト機能を追加
-- ========================================

CREATE OR REPLACE FUNCTION create_system_email(
    p_subject TEXT,
    p_body TEXT,
    p_send_to TEXT,  -- 'all', 'approved', 'unapproved', 'individual'
    p_individual_user_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE(
    email_id UUID,
    total_recipients INTEGER,
    blacklisted_count INTEGER,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email_id UUID;
    v_recipient_count INTEGER := 0;
    v_blacklisted_count INTEGER := 0;
    v_user_record RECORD;
BEGIN
    -- システムメール作成
    INSERT INTO system_emails (subject, body, send_to, created_at)
    VALUES (p_subject, p_body, p_send_to, NOW())
    RETURNING id INTO v_email_id;

    -- 送信先ユーザーを決定（email_blacklisted = FALSE のユーザーのみ）
    IF p_send_to = 'all' THEN
        -- 全ユーザー（除外リスト以外）
        FOR v_user_record IN
            SELECT user_id, email
            FROM users
            WHERE (email_blacklisted = FALSE OR email_blacklisted IS NULL)
            ORDER BY created_at DESC
        LOOP
            INSERT INTO email_recipients (email_id, user_id, recipient_email, status)
            VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
            v_recipient_count := v_recipient_count + 1;
        END LOOP;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(*) INTO v_blacklisted_count
        FROM users
        WHERE email_blacklisted = TRUE;

    ELSIF p_send_to = 'approved' THEN
        -- 承認済みユーザー（除外リスト以外）
        FOR v_user_record IN
            SELECT DISTINCT u.user_id, u.email
            FROM users u
            INNER JOIN purchases p ON u.user_id = p.user_id
            WHERE p.admin_approved = TRUE
              AND (u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL)
            ORDER BY u.created_at DESC
        LOOP
            INSERT INTO email_recipients (email_id, user_id, recipient_email, status)
            VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
            v_recipient_count := v_recipient_count + 1;
        END LOOP;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(DISTINCT u.user_id) INTO v_blacklisted_count
        FROM users u
        INNER JOIN purchases p ON u.user_id = p.user_id
        WHERE p.admin_approved = TRUE
          AND u.email_blacklisted = TRUE;

    ELSIF p_send_to = 'unapproved' THEN
        -- 未承認ユーザー（除外リスト以外）
        FOR v_user_record IN
            SELECT u.user_id, u.email
            FROM users u
            WHERE NOT EXISTS (
                SELECT 1 FROM purchases p
                WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
            )
            AND (u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL)
            ORDER BY u.created_at DESC
        LOOP
            INSERT INTO email_recipients (email_id, user_id, recipient_email, status)
            VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
            v_recipient_count := v_recipient_count + 1;
        END LOOP;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(*) INTO v_blacklisted_count
        FROM users u
        WHERE NOT EXISTS (
            SELECT 1 FROM purchases p
            WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
        )
        AND u.email_blacklisted = TRUE;

    ELSIF p_send_to = 'individual' AND p_individual_user_ids IS NOT NULL THEN
        -- 個別指定（除外リスト以外）
        FOR v_user_record IN
            SELECT user_id, email
            FROM users
            WHERE user_id = ANY(p_individual_user_ids)
              AND (email_blacklisted = FALSE OR email_blacklisted IS NULL)
        LOOP
            INSERT INTO email_recipients (email_id, user_id, recipient_email, status)
            VALUES (v_email_id, v_user_record.user_id, v_user_record.email, 'pending');
            v_recipient_count := v_recipient_count + 1;
        END LOOP;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(*) INTO v_blacklisted_count
        FROM users
        WHERE user_id = ANY(p_individual_user_ids)
          AND email_blacklisted = TRUE;
    END IF;

    -- 結果を返す
    RETURN QUERY SELECT
        v_email_id,
        v_recipient_count,
        v_blacklisted_count,
        FORMAT('メール作成完了: %s名に送信予定（%s名は除外リスト）',
               v_recipient_count, v_blacklisted_count)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'メール作成エラー: %', SQLERRM;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION create_system_email(TEXT, TEXT, TEXT, TEXT[]) TO authenticated;

SELECT '✅ create_system_email関数を更新しました' as status;
SELECT '📧 email_blacklisted = TRUE のユーザーは自動的にスキップされます' as note;
