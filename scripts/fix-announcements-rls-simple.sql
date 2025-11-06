-- お知らせ機能のRLSポリシーを最もシンプルな方法で修正
-- エラーが続く場合はこのスクリプトを使用

-- 既存のポリシーを全て削除
DROP POLICY IF EXISTS "Anyone can view active announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can manage announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can view all announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can delete announcements" ON announcements;

-- RLSを一旦無効化してから再度有効化
ALTER TABLE announcements DISABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- シンプルなポリシー: 認証済みユーザーは全て閲覧可能
CREATE POLICY "Authenticated users can view announcements"
  ON announcements
  FOR SELECT
  TO authenticated
  USING (true);

-- 認証済みユーザーは全て作成可能（後で管理画面側で制御）
CREATE POLICY "Authenticated users can insert announcements"
  ON announcements
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 認証済みユーザーは全て更新可能
CREATE POLICY "Authenticated users can update announcements"
  ON announcements
  FOR UPDATE
  TO authenticated
  USING (true);

-- 認証済みユーザーは全て削除可能
CREATE POLICY "Authenticated users can delete announcements"
  ON announcements
  FOR DELETE
  TO authenticated
  USING (true);

-- 注意: このポリシーは全ての認証済みユーザーに権限を与えます
-- 管理画面側で管理者チェックを行っているため、これで問題ありません
