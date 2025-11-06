-- お知らせ機能のRLSポリシー更新スクリプト
-- 既存のポリシーを削除してから新しいポリシーを作成

-- 既存のポリシーを全て削除
DROP POLICY IF EXISTS "Anyone can view active announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can manage announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can view all announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can delete announcements" ON announcements;

-- 新しいポリシーを作成

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

-- 管理者のみが作成可能
CREATE POLICY "Admins can manage announcements"
  ON announcements
  FOR INSERT
  WITH CHECK (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

-- 管理者のみが更新可能
CREATE POLICY "Admins can update announcements"
  ON announcements
  FOR UPDATE
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

-- 管理者のみが削除可能
CREATE POLICY "Admins can delete announcements"
  ON announcements
  FOR DELETE
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );
