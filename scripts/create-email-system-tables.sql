-- システムメール機能のテーブル作成
-- 作成日: 2025年10月11日
-- 目的: 管理者からユーザーへのメール送信機能（一斉送信・個別送信）

-- 1. system_emails テーブル（メール本体）
CREATE TABLE IF NOT EXISTS system_emails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    from_name TEXT DEFAULT 'HASHPILOT',
    from_email TEXT DEFAULT 'noreply@send.hashpilot.biz',
    email_type TEXT NOT NULL CHECK (email_type IN ('broadcast', 'individual')),
    sent_by TEXT NOT NULL, -- 管理者のメールアドレス
    target_group TEXT, -- 'all' / 'approved' / 'unapproved' / NULL（個別送信の場合）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_email_type CHECK (email_type IN ('broadcast', 'individual'))
);

-- 2. email_recipients テーブル（送信先・配信状況）
CREATE TABLE IF NOT EXISTS email_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id UUID NOT NULL REFERENCES system_emails(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    to_email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'read')),
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    error_message TEXT,
    resend_email_id TEXT, -- Resend APIからのメールID
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'sent', 'failed', 'read'))
);

-- 3. email_templates テーブル（メールテンプレート）（オプション・将来拡張用）
CREATE TABLE IF NOT EXISTS email_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    description TEXT,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_system_emails_created_at ON system_emails(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_emails_sent_by ON system_emails(sent_by);
CREATE INDEX IF NOT EXISTS idx_email_recipients_email_id ON email_recipients(email_id);
CREATE INDEX IF NOT EXISTS idx_email_recipients_user_id ON email_recipients(user_id);
CREATE INDEX IF NOT EXISTS idx_email_recipients_status ON email_recipients(status);
CREATE INDEX IF NOT EXISTS idx_email_recipients_created_at ON email_recipients(created_at DESC);

-- RLS（Row Level Security）設定
ALTER TABLE system_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;

-- 管理者はすべてのメールを参照・作成可能
CREATE POLICY "管理者は全てのメールを参照可能" ON system_emails
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.email = sent_by
            AND users.is_admin = true
        )
    );

CREATE POLICY "管理者は全てのメールを作成可能" ON system_emails
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.email = sent_by
            AND users.is_admin = true
        )
    );

-- ユーザーは自分宛てのメールのみ参照可能
CREATE POLICY "ユーザーは自分宛てのメールのみ参照可能" ON email_recipients
    FOR SELECT USING (
        user_id = (SELECT user_id FROM users WHERE email = auth.jwt()->>'email')
    );

-- ユーザーは自分のメールの既読状態を更新可能
CREATE POLICY "ユーザーは自分のメールの既読状態を更新可能" ON email_recipients
    FOR UPDATE USING (
        user_id = (SELECT user_id FROM users WHERE email = auth.jwt()->>'email')
    );

-- 管理者は全ての配信状況を参照可能
CREATE POLICY "管理者は全ての配信状況を参照可能" ON email_recipients
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.email = auth.jwt()->>'email'
            AND users.is_admin = true
        )
    );

-- 管理者は配信レコードを作成可能
CREATE POLICY "管理者は配信レコードを作成可能" ON email_recipients
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.email = auth.jwt()->>'email'
            AND users.is_admin = true
        )
    );

-- テンプレートのポリシー（管理者のみ）
CREATE POLICY "管理者のみテンプレート参照可能" ON email_templates
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.email = auth.jwt()->>'email'
            AND users.is_admin = true
        )
    );

CREATE POLICY "管理者のみテンプレート作成可能" ON email_templates
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.email = auth.jwt()->>'email'
            AND users.is_admin = true
        )
    );

-- 権限付与
GRANT ALL ON system_emails TO authenticated;
GRANT ALL ON email_recipients TO authenticated;
GRANT ALL ON email_templates TO authenticated;

-- 確認
SELECT
    '✅ Email system tables created successfully' as message,
    (SELECT COUNT(*) FROM system_emails) as emails_count,
    (SELECT COUNT(*) FROM email_recipients) as recipients_count,
    (SELECT COUNT(*) FROM email_templates) as templates_count;
