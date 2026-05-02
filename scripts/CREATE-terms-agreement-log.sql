-- ========================================
-- 利用規約同意ポップアップのデバッグログテーブル
-- クライアント側で起きたイベント（成功/失敗）を全て記録
-- ========================================

CREATE TABLE IF NOT EXISTS terms_agreement_log (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  user_id TEXT,
  user_email TEXT,
  auth_uid UUID,
  event TEXT NOT NULL,                -- 'attempt' / 'auth_failed' / 'update_failed' / 'no_rows' / 'success' / 'unexpected_error'
  error_message TEXT,
  rows_affected INTEGER,
  user_agent TEXT,
  context JSONB
);

CREATE INDEX IF NOT EXISTS idx_terms_log_user_id ON terms_agreement_log (user_id);
CREATE INDEX IF NOT EXISTS idx_terms_log_created_at ON terms_agreement_log (created_at DESC);

-- RLS: 誰でもINSERT可能（書き込みのみ）。SELECTは管理者のみ。
ALTER TABLE terms_agreement_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone_can_insert_terms_log" ON terms_agreement_log;
CREATE POLICY "anyone_can_insert_terms_log"
  ON terms_agreement_log
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "admins_can_view_terms_log" ON terms_agreement_log;
CREATE POLICY "admins_can_view_terms_log"
  ON terms_agreement_log
  FOR SELECT
  USING (is_admin((auth.jwt() ->> 'email'::text), auth.uid()));

GRANT INSERT ON terms_agreement_log TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE terms_agreement_log_id_seq TO anon, authenticated;

SELECT '✅ terms_agreement_log テーブルを作成しました' AS status;
