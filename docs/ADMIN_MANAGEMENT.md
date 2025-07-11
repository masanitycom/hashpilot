# 管理者アカウント管理ガイド

## 管理者アカウントの追加方法

### 1. Supabaseダッシュボードから追加

1. Supabaseダッシュボードにログイン
2. SQL Editorを開く
3. `/scripts/add-new-admin.sql`の内容をコピー
4. `'new-admin@example.com'`を新しい管理者のメールアドレスに置き換え
5. SQLを実行

### 2. 必要な設定

管理者として機能するには、以下の2つの設定が必要です：

#### A. usersテーブル
- `is_admin`フィールドを`true`に設定

#### B. adminsテーブル（存在する場合）
- 管理者のレコードを追加
- `role`: 'admin' または 'super_admin'
- `is_active`: true

### 3. 管理者の種類

- **admin**: 通常の管理者権限
- **super_admin**: 最高管理者権限（basarasystems@gmail.comなど）

### 4. 管理者アカウントの特徴

- ユーザー向けページにアクセスできない（自動的に/adminにリダイレクト）
- 統計やユーザー数のカウントから除外される
- 管理画面のみアクセス可能

### 5. 既存の管理者確認

```sql
-- 全管理者を確認
SELECT 
    u.email,
    u.is_admin,
    a.role,
    a.is_active
FROM users u
LEFT JOIN admins a ON u.email = a.email
WHERE u.is_admin = true OR a.id IS NOT NULL;
```

### 6. 管理者権限の削除

```sql
-- 管理者権限を削除
UPDATE users SET is_admin = false WHERE email = 'admin-to-remove@example.com';
DELETE FROM admins WHERE email = 'admin-to-remove@example.com';
```

### 7. トラブルシューティング

#### 管理者がログインできない場合
1. `is_admin` RPC関数が正しく動作しているか確認
2. usersテーブルの`is_admin`フィールドが`true`か確認
3. adminsテーブルにレコードが存在し、`is_active`が`true`か確認

#### 緊急アクセス
basarasystems@gmail.comは、ハードコードされた緊急アクセス権限を持っています。
他の管理者が全員ログインできない場合でも、このアカウントはアクセス可能です。