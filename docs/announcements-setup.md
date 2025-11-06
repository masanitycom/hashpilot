# お知らせ機能のセットアップ手順

## 📋 データベーステーブル作成

お知らせ機能を使用する前に、Supabaseでテーブルを作成する必要があります。

### ステップ1: Supabase SQL Editorにアクセス

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. **Staging環境**: `objpuphnhcjxrsiydjbf` プロジェクトを選択
3. 左サイドバーから「SQL Editor」をクリック

### ステップ2: SQLスクリプトを実行

#### 新規作成の場合

以下のSQLスクリプトをコピーして実行します：

```sql
-- お知らせ機能のテーブル作成

-- お知らせテーブル
CREATE TABLE IF NOT EXISTS announcements (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  priority INTEGER DEFAULT 0,
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
```

#### 既にテーブルが存在する場合（ポリシーのみ更新）

テーブルが既に存在し、ポリシーエラーが出る場合は以下のスクリプトを実行：

```sql
-- 既存のポリシーを削除してから新しいポリシーを作成
DROP POLICY IF EXISTS "Anyone can view active announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can manage announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can view all announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON announcements;
DROP POLICY IF EXISTS "Admins can delete announcements" ON announcements;

-- 新しいポリシーを作成
CREATE POLICY "Anyone can view active announcements"
  ON announcements
  FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can view all announcements"
  ON announcements
  FOR SELECT
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) IN (
      'basarasystems@gmail.com',
      'support@dshsupport.biz'
    )
  );

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
```

または、`scripts/update-announcements-rls.sql` ファイルの内容を実行してください。

### ステップ3: 実行確認

「RUN」ボタンをクリックして、成功メッセージを確認します。

---

## 🎯 本番環境へのデプロイ

本番環境 (`soghqozaxfswtxxbgeer`) でも同じSQLスクリプトを実行してください。

---

## ✅ 動作確認

### 管理画面で確認
1. https://hashpilot-staging.vercel.app/admin/announcements にアクセス
2. 「新規作成」ボタンをクリック
3. テストお知らせを作成

### ユーザー画面で確認
1. https://hashpilot-staging.vercel.app/dashboard にアクセス
2. 作成したお知らせがダッシュボード上部に表示されることを確認

---

## 🚨 トラブルシューティング

### エラー: "Could not find the table 'public.announcements'"
→ SQLスクリプトが実行されていません。上記のステップ2を実行してください。

### エラー: "permission denied for table announcements"
→ RLSポリシーが正しく設定されていません。上記のSQLスクリプトを再実行してください。

---

**最終更新**: 2025年11月7日
