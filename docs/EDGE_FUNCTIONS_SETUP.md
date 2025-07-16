# Edge Functions セットアップガイド

## 🔑 Resend APIキー設定

### Supabaseダッシュボードでの設定

1. **Supabaseダッシュボードにアクセス**
   - https://supabase.com/dashboard
   - プロジェクト「HASHPILOT」を選択

2. **Edge Functions設定**
   - 左サイドバー → Settings → Edge Functions
   - Environment variables セクションを探す

3. **環境変数の追加**
   ```
   Name: RESEND_API_KEY
   Value: re_HYTVaBRo_PC2heZQdvhsBasAppFVpgoLZ
   ```

## 🚀 Edge Functions デプロイ

### 方法1: Supabaseダッシュボード（推奨）

1. **Edge Functions ページ**
   - 左サイドバー → Edge Functions
   - Create a new function

2. **関数作成**
   ```
   Function name: send-approval-email
   ```

3. **コードのコピー&ペースト**
   - `supabase/functions/send-approval-email/index.ts` の内容をコピー
   - エディターにペーストして Deploy

### 方法2: Git統合（自動デプロイ）

1. **GitHub連携**
   - Settings → Integration → GitHub
   - リポジトリを接続

2. **自動デプロイ設定**
   - `supabase/functions/` フォルダの変更を自動検出
   - プッシュ時に自動デプロイ

## 🧪 動作テスト

### テスト手順

1. **NFT購入承認テスト**
   - 管理画面 → Purchases
   - テスト購入を承認
   - メールが送信されるか確認

2. **ログ確認**
   ```sql
   SELECT * FROM system_logs 
   WHERE operation = 'send_approval_email' 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```

3. **Edge Functions ログ確認**
   - Supabaseダッシュボード → Edge Functions → send-approval-email
   - Logs タブでエラーログを確認

## 🔧 トラブルシューティング

### メール送信エラー

**症状**: 「Failed to send email」エラー
**原因**: APIキー設定不備
**解決**:
1. 環境変数が正しく設定されているか確認
2. ResendのAPIキーが有効か確認
3. ドメイン設定（hashpilot.net）が完了しているか確認

### Edge Functions デプロイエラー

**症状**: 関数がデプロイされない
**解決**:
1. コードの構文エラーをチェック
2. 必要な import文が正しいか確認
3. Deno ランタイム対応のライブラリを使用

### 環境変数エラー

**症状**: 「RESEND_API_KEY environment variable is required」
**解決**:
1. Supabaseダッシュボードで環境変数を再設定
2. 関数を再デプロイ
3. しばらく待ってから再テスト（反映に時間がかかる場合）

## 📋 確認項目チェックリスト

### 設定完了チェック
- [ ] Resend APIキーが環境変数に設定済み
- [ ] Edge Function `send-approval-email` がデプロイ済み
- [ ] フロントエンドの変更がデプロイ済み
- [ ] テスト購入でメール送信が動作

### 本番運用チェック
- [ ] 実際のユーザーでNFT購入承認テスト
- [ ] メール内容が正しく表示される
- [ ] システムログに記録される
- [ ] ブラウザキャッシュ問題が解消されている

## 🎯 期待される動作

### 正常フロー
1. ユーザーがNFT購入申請
2. 管理者が承認ボタンクリック
3. 自動でEdge Functionが実行
4. Resend経由でHTMLメール送信
5. システムログに成功記録
6. 管理者に「承認完了メールを送信しました」通知

### メール内容
- NFT購入承認のお祝いメッセージ
- 購入詳細（数量、金額、ユーザーID等）
- 翌日から利益開始の説明
- ダッシュボードリンク
- よくある質問への回答

---

**APIキー**: `re_HYTVaBRo_PC2heZQdvhsBasAppFVpgoLZ`  
**設定完了後**: NFT承認時に自動メール送信開始  
**重要**: 本番環境でのテストを必ず実施してください