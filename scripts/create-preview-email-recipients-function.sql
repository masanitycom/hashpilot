-- ========================================
-- メール送信対象者のプレビュー関数
-- 実際には送信せず、対象者数と除外者数のみ返す
-- ========================================

CREATE OR REPLACE FUNCTION preview_email_recipients(
    p_send_to TEXT,  -- 'all', 'approved', 'unapproved', 'individual'
    p_individual_user_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE(
    total_recipients INTEGER,
    blacklisted_count INTEGER,
    sample_recipients TEXT[],
    sample_blacklisted TEXT[],
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recipient_count INTEGER := 0;
    v_blacklisted_count INTEGER := 0;
    v_sample_recipients TEXT[];
    v_sample_blacklisted TEXT[];
BEGIN
    -- 送信先ユーザーを決定（email_blacklisted = FALSE のユーザーのみ）
    IF p_send_to = 'all' THEN
        -- 全ユーザー（除外リスト以外）
        SELECT COUNT(*) INTO v_recipient_count
        FROM users
        WHERE (email_blacklisted = FALSE OR email_blacklisted IS NULL);

        -- サンプル5件取得
        SELECT ARRAY_AGG(email ORDER BY created_at DESC) INTO v_sample_recipients
        FROM (
            SELECT email FROM users
            WHERE (email_blacklisted = FALSE OR email_blacklisted IS NULL)
            ORDER BY created_at DESC
            LIMIT 5
        ) sample;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(*) INTO v_blacklisted_count
        FROM users
        WHERE email_blacklisted = TRUE;

        -- 除外ユーザーサンプル5件取得
        SELECT ARRAY_AGG(email ORDER BY created_at DESC) INTO v_sample_blacklisted
        FROM (
            SELECT email FROM users
            WHERE email_blacklisted = TRUE
            ORDER BY created_at DESC
            LIMIT 5
        ) sample;

    ELSIF p_send_to = 'approved' THEN
        -- 承認済みユーザー（除外リスト以外）
        SELECT COUNT(DISTINCT u.user_id) INTO v_recipient_count
        FROM users u
        INNER JOIN purchases p ON u.user_id = p.user_id
        WHERE p.admin_approved = TRUE
          AND (u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL);

        -- サンプル5件取得
        SELECT ARRAY_AGG(email) INTO v_sample_recipients
        FROM (
            SELECT DISTINCT u.email
            FROM users u
            INNER JOIN purchases p ON u.user_id = p.user_id
            WHERE p.admin_approved = TRUE
              AND (u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL)
            ORDER BY u.created_at DESC
            LIMIT 5
        ) sample;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(DISTINCT u.user_id) INTO v_blacklisted_count
        FROM users u
        INNER JOIN purchases p ON u.user_id = p.user_id
        WHERE p.admin_approved = TRUE
          AND u.email_blacklisted = TRUE;

        -- 除外ユーザーサンプル5件取得
        SELECT ARRAY_AGG(email) INTO v_sample_blacklisted
        FROM (
            SELECT DISTINCT u.email
            FROM users u
            INNER JOIN purchases p ON u.user_id = p.user_id
            WHERE p.admin_approved = TRUE
              AND u.email_blacklisted = TRUE
            ORDER BY u.created_at DESC
            LIMIT 5
        ) sample;

    ELSIF p_send_to = 'unapproved' THEN
        -- 未承認ユーザー（除外リスト以外）
        SELECT COUNT(*) INTO v_recipient_count
        FROM users u
        WHERE NOT EXISTS (
            SELECT 1 FROM purchases p
            WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
        )
        AND (u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL);

        -- サンプル5件取得
        SELECT ARRAY_AGG(email ORDER BY created_at DESC) INTO v_sample_recipients
        FROM (
            SELECT email, created_at FROM users u
            WHERE NOT EXISTS (
                SELECT 1 FROM purchases p
                WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
            )
            AND (u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL)
            ORDER BY created_at DESC
            LIMIT 5
        ) sample;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(*) INTO v_blacklisted_count
        FROM users u
        WHERE NOT EXISTS (
            SELECT 1 FROM purchases p
            WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
        )
        AND u.email_blacklisted = TRUE;

        -- 除外ユーザーサンプル5件取得
        SELECT ARRAY_AGG(email ORDER BY created_at DESC) INTO v_sample_blacklisted
        FROM (
            SELECT email, created_at FROM users u
            WHERE NOT EXISTS (
                SELECT 1 FROM purchases p
                WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
            )
            AND u.email_blacklisted = TRUE
            ORDER BY created_at DESC
            LIMIT 5
        ) sample;

    ELSIF p_send_to = 'individual' AND p_individual_user_ids IS NOT NULL THEN
        -- 個別指定（除外リスト以外）
        SELECT COUNT(*) INTO v_recipient_count
        FROM users
        WHERE user_id = ANY(p_individual_user_ids)
          AND (email_blacklisted = FALSE OR email_blacklisted IS NULL);

        -- サンプル5件取得
        SELECT ARRAY_AGG(email) INTO v_sample_recipients
        FROM (
            SELECT email FROM users
            WHERE user_id = ANY(p_individual_user_ids)
              AND (email_blacklisted = FALSE OR email_blacklisted IS NULL)
            LIMIT 5
        ) sample;

        -- 除外されたユーザー数をカウント
        SELECT COUNT(*) INTO v_blacklisted_count
        FROM users
        WHERE user_id = ANY(p_individual_user_ids)
          AND email_blacklisted = TRUE;

        -- 除外ユーザーサンプル5件取得
        SELECT ARRAY_AGG(email) INTO v_sample_blacklisted
        FROM (
            SELECT email FROM users
            WHERE user_id = ANY(p_individual_user_ids)
              AND email_blacklisted = TRUE
            LIMIT 5
        ) sample;
    END IF;

    -- 結果を返す
    RETURN QUERY SELECT
        v_recipient_count,
        v_blacklisted_count,
        v_sample_recipients,
        v_sample_blacklisted,
        FORMAT('送信対象: %s名 / 除外: %s名',
               v_recipient_count, v_blacklisted_count)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'プレビューエラー: %', SQLERRM;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION preview_email_recipients(TEXT, TEXT[]) TO authenticated;

-- テスト
SELECT * FROM preview_email_recipients('all', NULL);

SELECT '✅ preview_email_recipients関数を作成しました' as status;
SELECT '📧 メール送信前に対象者数と除外者数を確認できます' as note;
