# support@dshsupport.biz を管理者として追加する手順

## ステップ1: Supabase Authenticationでユーザーを作成

1. **Supabase Dashboardにログイン**

2. **Authentication → Users** に移動

3. **"Invite user"** ボタンをクリック

4. 以下の情報を入力:
   - Email: `support@dshsupport.biz`
   - Password: `mU4W9KvH`

5. **"Send Invitation"** をクリック（または"Create User"）

6. ユーザーが作成されたことを確認

## ステップ2: SQLで管理者権限を付与

1. **SQL Editor** に移動

2. 以下のSQLを実行して、ユーザーが存在することを確認:
```sql
SELECT * FROM users WHERE email = 'support@dshsupport.biz';
```

3. ユーザーが存在する場合、管理者権限を付与:
```sql
UPDATE users
SET is_admin = true
WHERE email = 'support@dshsupport.biz';
```

4. 確認:
```sql
SELECT email, is_admin FROM users WHERE email = 'support@dshsupport.biz';
```

## ステップ3: アプリケーションでの対応

すでに実装済みですが、support@dshsupport.bizも管理者専用アカウントとして扱われます：
- ユーザー画面にはアクセスできません
- 自動的に/adminにリダイレクトされます
- 統計から除外されます

## トラブルシューティング

### "User not found"エラーが出る場合
- Authenticationでユーザーが作成されているか確認
- メールアドレスのスペルミスがないか確認

### ログインできない場合
- パスワードが正しいか確認
- is_adminがtrueになっているか確認

## セキュリティ注意事項
- このドキュメントをプロダクション環境に含めないでください
- パスワードは初回ログイン後に変更することを推奨します