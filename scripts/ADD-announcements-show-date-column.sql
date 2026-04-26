-- ========================================
-- announcementsテーブルにshow_dateカラムを追加
-- 投稿ごとに日付の表示/非表示を切り替えられるようにする
-- ========================================

-- カラム追加（既存投稿はデフォルトでtrue＝今まで通り日付を表示）
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS show_date BOOLEAN DEFAULT TRUE;

-- 確認
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'announcements' AND column_name = 'show_date';

SELECT '✅ show_date カラムを追加しました' as status;
