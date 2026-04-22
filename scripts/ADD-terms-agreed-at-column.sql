-- ========================================
-- usersテーブルにterms_agreed_atカラムを追加
-- 利用規約同意日時を記録（同意済みユーザーには二度と同意画面を表示しないため）
-- ========================================

-- カラム追加（既存処理には影響なし）
ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_agreed_at TIMESTAMPTZ DEFAULT NULL;

-- 確認
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'terms_agreed_at';

SELECT '✅ terms_agreed_at カラムを追加しました' as status;
