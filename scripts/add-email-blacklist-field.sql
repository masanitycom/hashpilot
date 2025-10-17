-- ========================================
-- メール送信除外リスト機能
-- ========================================

-- email_blacklisted カラムを追加
ALTER TABLE users
ADD COLUMN IF NOT EXISTS email_blacklisted BOOLEAN DEFAULT FALSE;

-- インデックス追加（除外ユーザーの検索を高速化）
CREATE INDEX IF NOT EXISTS idx_users_email_blacklisted
ON users(email_blacklisted)
WHERE email_blacklisted = TRUE;

-- コメント追加
COMMENT ON COLUMN users.email_blacklisted IS 'メール送信除外フラグ（trueの場合、一斉送信の対象外）';

-- 確認
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'email_blacklisted';

SELECT '✅ email_blacklisted カラムを追加しました' as status;
SELECT '📧 このフラグがtrueのユーザーは一斉送信の対象外になります' as note;
