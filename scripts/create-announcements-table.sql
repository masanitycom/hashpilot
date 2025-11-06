-- お知らせ機能のテーブル作成

-- お知らせテーブル
CREATE TABLE IF NOT EXISTS announcements (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  priority INTEGER DEFAULT 0, -- 数字が大きいほど上に表示
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_announcements_active ON announcements(is_active);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON announcements(priority DESC);

-- RLS（Row Level Security）設定
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- 全ユーザーが有効なお知らせを閲覧可能
CREATE POLICY "Anyone can view active announcements"
  ON announcements
  FOR SELECT
  USING (is_active = true);

-- 管理者のみが全てのお知らせを閲覧可能
CREATE POLICY "Admins can view all announcements"
  ON announcements
  FOR SELECT
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

-- 管理者のみが作成・更新・削除可能
CREATE POLICY "Admins can manage announcements"
  ON announcements
  FOR INSERT
  WITH CHECK (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

CREATE POLICY "Admins can update announcements"
  ON announcements
  FOR UPDATE
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

CREATE POLICY "Admins can delete announcements"
  ON announcements
  FOR DELETE
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

-- コメント追加
COMMENT ON TABLE announcements IS 'お知らせ機能：管理者が入力したお知らせをユーザーダッシュボードに表示';
COMMENT ON COLUMN announcements.title IS 'お知らせタイトル';
COMMENT ON COLUMN announcements.content IS 'お知らせ本文（プレーンテキスト、改行とURLは自動変換）';
COMMENT ON COLUMN announcements.is_active IS '表示/非表示フラグ';
COMMENT ON COLUMN announcements.priority IS '表示優先度（数字が大きいほど上）';
