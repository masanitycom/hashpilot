# Cloudflare Email Receiver Worker

support@hashpilot.biz 宛のメールを受信してSupabaseに保存するWorkerです。

## セットアップ手順

### 1. Supabaseでテーブルとファンクションを作成

```bash
# scripts/ADD-email-inbox-feature.sql をSupabaseで実行
```

このスクリプトは以下を作成します：
- `received_emails` テーブル
- `save_received_email` RPC関数
- `get_received_emails` RPC関数
- `mark_received_email_as_read` RPC関数
- RLSポリシー

### 2. Cloudflare Workerを作成

**方法A: Cloudflare Dashboard（簡単）**

1. [Cloudflare Dashboard](https://dash.cloudflare.com) にログイン
2. **Workers & Pages** をクリック
3. **Create Worker** をクリック
4. 名前を `hashpilot-email-receiver` に設定
5. `worker.js` の内容をコピーして貼り付け
6. **Deploy** をクリック

**方法B: Wrangler CLI**

```bash
cd cloudflare-workers/email-receiver
npm install -g wrangler
wrangler login
wrangler deploy
```

### 3. 環境変数を設定

Cloudflare Dashboard > Workers & Pages > hashpilot-email-receiver > Settings > Variables

以下の変数を追加：

| 変数名 | 値 |
|--------|-----|
| SUPABASE_URL | `https://soghqozaxfswtxxbgeer.supabase.co` |
| SUPABASE_SERVICE_KEY | `eyJhbGci...`（service_role キー） |

⚠️ **重要**: `SUPABASE_SERVICE_KEY` には **service_role キー** を使用してください（anonキーではありません）

### 4. Email Routingを設定

Cloudflare Dashboard > hashpilot.biz > Email > Email Routing > Email Workers

1. **Email Workers** タブをクリック
2. **Create rule** をクリック
3. 設定：
   - **From**: `*` (all)
   - **To**: `support@hashpilot.biz`
   - **Action**: `Send to a Worker`
   - **Worker**: `hashpilot-email-receiver`
4. **Save** をクリック

### 5. テスト

support@hashpilot.biz にテストメールを送信し、管理画面の受信箱に表示されることを確認してください。

## トラブルシューティング

### メールが受信箱に表示されない

1. **Cloudflare Logs を確認**
   - Workers & Pages > hashpilot-email-receiver > Logs
   - エラーメッセージを確認

2. **環境変数を確認**
   - SUPABASE_URL と SUPABASE_SERVICE_KEY が正しく設定されているか

3. **Email Routingの設定を確認**
   - support@hashpilot.biz が正しくWorkerに紐付けられているか

4. **Supabaseの権限を確認**
   - `save_received_email` 関数が `SECURITY DEFINER` になっているか
   - RLSポリシーが正しく設定されているか

### 既存の転送設定との共存

Email Routingでは、1つのアドレスに対して複数のアクションを設定できます。
Workerで処理した後に転送も行いたい場合は、worker.js の以下の行をコメント解除：

```javascript
await message.forward("masataka.tak@gmail.com");
```

## ファイル構成

```
email-receiver/
├── worker.js      # メインのWorkerコード
├── wrangler.toml  # Wrangler設定ファイル
└── README.md      # このファイル
```
