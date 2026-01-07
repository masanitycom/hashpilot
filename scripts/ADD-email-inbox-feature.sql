-- =====================================================
-- メール受信箱機能追加スクリプト
-- 1. create_system_email 関数に送信元アドレス選択機能を追加
-- 2. 受信メール保存テーブルを作成
-- 3. 受信メール保存用RPC関数を作成
-- =====================================================

-- =====================================================
-- STEP 1: create_system_email 関数を更新（送信元アドレス対応）
-- =====================================================
CREATE OR REPLACE FUNCTION create_system_email(
    p_subject TEXT,
    p_body TEXT,
    p_email_type TEXT,           -- 'broadcast' or 'individual'
    p_admin_email TEXT,          -- 送信者（管理者）のメール
    p_target_group TEXT DEFAULT NULL,  -- 'all', 'approved', 'unapproved'
    p_target_user_ids TEXT[] DEFAULT NULL,  -- 個別送信時のユーザーID配列
    p_from_email TEXT DEFAULT 'noreply@send.hashpilot.biz'  -- 送信元アドレス（新規追加）
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email_id UUID;
    v_recipient_count INT := 0;
    v_html_body TEXT;
    v_from_name TEXT := 'HASHPILOT';
BEGIN
    -- 送信元に応じて送信者名を設定
    IF p_from_email = 'support@hashpilot.biz' THEN
        v_from_name := 'HASHPILOT Support';
    END IF;

    -- 本文をHTML形式に変換（改行をbrタグに）
    v_html_body := '<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { font-family: "Helvetica Neue", Arial, sans-serif; line-height: 1.8; color: #333; background-color: #f5f5f5; margin: 0; padding: 0; }
.container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
.header { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); padding: 30px 20px; text-align: center; }
.header h1 { color: #ffffff; margin: 0; font-size: 24px; font-weight: 600; }
.content { padding: 30px 20px; }
.footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #666; border-top: 1px solid #eee; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>HASH PILOT NFT</h1>
</div>
<div class="content">' || REPLACE(p_body, E'\n', '<br>') || '</div>
<div class="footer">
<p>このメールは HASH PILOT NFT からの自動送信です。</p>
<p>&copy; 2025 HASH PILOT NFT. All rights reserved.</p>
</div>
</div>
</body>
</html>';

    -- メール本体を作成
    INSERT INTO system_emails (
        subject,
        body,
        from_name,
        from_email,
        email_type,
        sent_by,
        target_group
    ) VALUES (
        p_subject,
        v_html_body,
        v_from_name,
        p_from_email,  -- 選択された送信元アドレスを使用
        p_email_type,
        p_admin_email,
        p_target_group
    )
    RETURNING id INTO v_email_id;

    -- 送信先を登録
    IF p_email_type = 'broadcast' THEN
        -- 一斉送信
        INSERT INTO email_recipients (email_id, user_id, to_email, status)
        SELECT
            v_email_id,
            user_id,
            email,
            'pending'
        FROM users
        WHERE
            (p_target_group = 'all')
            OR (p_target_group = 'approved' AND has_approved_nft = true)
            OR (p_target_group = 'unapproved' AND has_approved_nft = false);

        GET DIAGNOSTICS v_recipient_count = ROW_COUNT;
    ELSE
        -- 個別送信
        IF p_target_user_ids IS NOT NULL AND array_length(p_target_user_ids, 1) > 0 THEN
            INSERT INTO email_recipients (email_id, user_id, to_email, status)
            SELECT
                v_email_id,
                user_id,
                email,
                'pending'
            FROM users
            WHERE user_id = ANY(p_target_user_ids);

            GET DIAGNOSTICS v_recipient_count = ROW_COUNT;
        END IF;
    END IF;

    RETURN json_build_object(
        'email_id', v_email_id,
        'recipient_count', v_recipient_count
    );
END;
$$;

-- =====================================================
-- STEP 2: 受信メール保存テーブルを作成
-- =====================================================
CREATE TABLE IF NOT EXISTS received_emails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id TEXT,                    -- メールのMessage-ID
    from_email TEXT NOT NULL,           -- 送信元メールアドレス
    from_name TEXT,                     -- 送信者名
    to_email TEXT NOT NULL,             -- 宛先（support@hashpilot.biz等）
    subject TEXT,                       -- 件名
    body_text TEXT,                     -- 本文（プレーンテキスト）
    body_html TEXT,                     -- 本文（HTML）
    received_at TIMESTAMPTZ DEFAULT NOW(), -- 受信日時
    is_read BOOLEAN DEFAULT FALSE,      -- 既読フラグ
    is_replied BOOLEAN DEFAULT FALSE,   -- 返信済みフラグ
    replied_at TIMESTAMPTZ,             -- 返信日時
    reply_email_id UUID,                -- 返信メールのID（system_emailsへの参照）
    raw_headers JSONB,                  -- 元のヘッダー情報
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_received_emails_received_at ON received_emails(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_received_emails_from_email ON received_emails(from_email);
CREATE INDEX IF NOT EXISTS idx_received_emails_is_read ON received_emails(is_read);
CREATE INDEX IF NOT EXISTS idx_received_emails_to_email ON received_emails(to_email);

-- =====================================================
-- STEP 3: 受信メール保存用RPC関数
-- （Cloudflare Email Workerから呼び出される）
-- =====================================================
CREATE OR REPLACE FUNCTION save_received_email(
    p_message_id TEXT,
    p_from_email TEXT,
    p_from_name TEXT,
    p_to_email TEXT,
    p_subject TEXT,
    p_body_text TEXT,
    p_body_html TEXT,
    p_raw_headers JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email_id UUID;
BEGIN
    INSERT INTO received_emails (
        message_id,
        from_email,
        from_name,
        to_email,
        subject,
        body_text,
        body_html,
        raw_headers
    ) VALUES (
        p_message_id,
        p_from_email,
        p_from_name,
        p_to_email,
        p_subject,
        p_body_text,
        p_body_html,
        p_raw_headers
    )
    RETURNING id INTO v_email_id;

    RETURN v_email_id;
END;
$$;

-- =====================================================
-- STEP 4: 受信メール一覧取得RPC関数
-- =====================================================
CREATE OR REPLACE FUNCTION get_received_emails(
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0,
    p_unread_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    id UUID,
    message_id TEXT,
    from_email TEXT,
    from_name TEXT,
    to_email TEXT,
    subject TEXT,
    body_text TEXT,
    body_html TEXT,
    received_at TIMESTAMPTZ,
    is_read BOOLEAN,
    is_replied BOOLEAN,
    replied_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        re.id,
        re.message_id,
        re.from_email,
        re.from_name,
        re.to_email,
        re.subject,
        re.body_text,
        re.body_html,
        re.received_at,
        re.is_read,
        re.is_replied,
        re.replied_at
    FROM received_emails re
    WHERE
        (NOT p_unread_only OR re.is_read = FALSE)
    ORDER BY re.received_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- =====================================================
-- STEP 5: 受信メールを既読にするRPC関数
-- =====================================================
CREATE OR REPLACE FUNCTION mark_received_email_as_read(
    p_email_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE received_emails
    SET is_read = TRUE
    WHERE id = p_email_id;

    RETURN FOUND;
END;
$$;

-- =====================================================
-- STEP 6: RLSポリシー設定
-- =====================================================
ALTER TABLE received_emails ENABLE ROW LEVEL SECURITY;

-- 管理者のみ閲覧可能（is_admin RPC関数を使用）
CREATE POLICY "管理者のみ受信メール閲覧可能" ON received_emails
    FOR SELECT
    TO authenticated
    USING (
        is_admin((auth.jwt() ->> 'email'::text), auth.uid())
    );

-- 管理者のみ更新可能
CREATE POLICY "管理者のみ受信メール更新可能" ON received_emails
    FOR UPDATE
    TO authenticated
    USING (
        is_admin((auth.jwt() ->> 'email'::text), auth.uid())
    );

-- サービスロールは全操作可能（Email Worker用）
CREATE POLICY "サービスロール受信メール挿入可能" ON received_emails
    FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "サービスロール受信メール全操作可能" ON received_emails
    FOR ALL
    TO service_role
    USING (true);

-- =====================================================
-- 実行確認
-- =====================================================
SELECT 'Email inbox feature tables and functions created successfully!' as status;
