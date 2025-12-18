-- ========================================
-- usersテーブルにchannel_linked_confirmedカラムを追加
-- チャンネル紐付け確認用（報酬等には影響なし）
-- ========================================

-- カラム追加
ALTER TABLE users ADD COLUMN IF NOT EXISTS channel_linked_confirmed BOOLEAN DEFAULT FALSE;

-- 確認
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'channel_linked_confirmed';

SELECT '✅ channel_linked_confirmed カラムを追加しました' as status;
