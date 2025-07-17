# 🚨 緊急修正実行手順

## RLSポリシー修正でダッシュボード復旧

### 手順
1. **Supabaseダッシュボードにアクセス**
   - https://supabase.com/dashboard/project/soghqozaxfswtxxbgeer

2. **SQL Editorを開く**
   - 左メニューから「SQL Editor」をクリック

3. **緊急修正スクリプトを実行**
   - `/scripts/EMERGENCY_FIX_RLS_POLICIES.sql` の内容をコピー
   - SQL Editorに貼り付け
   - 「Run」ボタンをクリック

### 期待される結果
- ユーザーテーブルのデータが表示される
- User 7A9637の情報が正常に取得できる
- ダッシュボードでの「ユーザー情報取得エラー」が解消される

### 修正後の確認
外部ツールを再実行してください：
```bash
cd external-tools
node debug-calculator.js
```

または管理者用HTMLツールでテスト：
```
external-tools/admin-calculator.html
```