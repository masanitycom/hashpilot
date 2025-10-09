-- usersテーブルにis_operation_onlyフィールドを追加
-- 作成日: 2025年10月9日
-- 目的: 紹介機能を使わない運用専用ユーザーを管理

-- is_operation_onlyフィールドを追加
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_operation_only BOOLEAN DEFAULT FALSE;

-- コメントを追加
COMMENT ON COLUMN users.is_operation_only IS '運用専用ユーザーフラグ（trueの場合、紹介UIを非表示）';

-- 既存ユーザーは全てfalse（デフォルト値が適用される）
-- 新規ユーザーもデフォルトでfalse

SELECT
    '✅ is_operation_only フィールド追加完了' as message,
    COUNT(*) as total_users,
    SUM(CASE WHEN is_operation_only = true THEN 1 ELSE 0 END) as operation_only_users
FROM users;
