# Resend アカウント設定手順

Resend: メール送信API（承認メール、送金完了メール、一括送信用）

---

## 🚀 STEP 1: アカウント作成

1. **Resend公式サイトにアクセス**
   - https://resend.com

2. **Sign Up（無料登録）**
   - 「Get Started」または「Sign Up」をクリック
   - GitHubアカウントでログイン（推奨）
   - または、メールアドレスで登録

3. **メール認証**
   - 登録メールアドレスに認証メールが届く
   - リンクをクリックして認証完了

---

## 🔐 STEP 2: API Key取得

1. **ダッシュボードにログイン**
   - https://resend.com/dashboard

2. **API Keysページへ移動**
   - 左メニュー → **API Keys**

3. **新しいAPI Keyを作成**
   - 「Create API Key」ボタンをクリック
   - 名前: `HASHPILOT Production`
   - Permission: **Full access** (または Sending access)
   - 「Create」をクリック

4. **API Keyをコピー**
   ```
   re_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   - ⚠️ このキーは一度しか表示されません
   - 安全な場所に保存してください

---

## 🌐 STEP 3: ドメイン認証（hashpilot.biz）

### 3-1. ドメインを追加

1. **Domainsページへ移動**
   - 左メニュー → **Domains**

2. **ドメインを追加**
   - 「Add Domain」ボタンをクリック
   - ドメイン名: `hashpilot.biz` を入力
   - 「Add Domain」をクリック

### 3-2. DNS レコードを追加

Resendが表示するDNSレコードをドメインのDNS設定に追加します。

**表示される情報例**:
```
Type: TXT
Name: resend._domainkey.hashpilot.biz
Value: p=MIGfMA0GCSqGSIb3DQEBAQUAA4...（長い文字列）

Type: TXT
Name: hashpilot.biz
Value: v=spf1 include:resend.io ~all

Type: CNAME
Name: resend._domainkey
Value: resend._domainkey.resend.io
```

### 3-3. DNS設定を追加（お名前.com / Cloudflare / その他）

#### お名前.comの場合:
1. お名前.com にログイン
2. ドメイン設定 → DNS設定
3. hashpilot.biz を選択
4. Resendが指定したレコードを追加

#### Cloudflareの場合:
1. Cloudflareにログイン
2. hashpilot.biz を選択
3. DNS → Records
4. Resendが指定したレコードを追加

### 3-4. 認証確認

1. DNSレコード追加後、Resendに戻る
2. 「Verify Domain」ボタンをクリック
3. ステータスが **Verified** になれば完了

⚠️ DNS反映に最大48時間かかる場合がありますが、通常は数分〜数時間で完了

---

## 📧 STEP 4: 送信元メールアドレス設定

### 4-1. auth@hashpilot.biz

1. **Domainsページ**で hashpilot.biz をクリック
2. **Verified Emails** セクション
3. 「Add Email」をクリック
4. メールアドレス: `auth@hashpilot.biz` を入力
5. 保存

### 4-2. withdrawal@hashpilot.biz（将来用）

同様に追加:
- `withdrawal@hashpilot.biz`

### 4-3. noreply@hashpilot.biz（将来用）

同様に追加:
- `noreply@hashpilot.biz`

---

## 🔧 STEP 5: Supabase Edge Functionに設定

### 5-1. SupabaseダッシュボードでAPI Key設定

1. **Supabaseダッシュボード**にログイン
   - https://supabase.com/dashboard

2. **Settings → Edge Functions**

3. **Environment Variables**
   - 「Add variable」をクリック
   - Name: `RESEND_API_KEY`
   - Value: （STEP 2でコピーしたAPI Key）
   - 「Save」をクリック

### 5-2. 確認

Edge Function（send-approval-email）が自動的にこのAPI Keyを使用します。

---

## ✅ 動作確認

### テスト送信

1. **Resendダッシュボード → API Keys**
2. 「Send test email」機能を使用
3. From: `auth@hashpilot.biz`
4. To: 自分のメールアドレス
5. 送信確認

### 本番確認

1. 管理画面からNFT承認を実行
2. 承認メールが auth@hashpilot.biz から届くか確認

---

## 💰 料金プラン

### 無料プラン（開始時）
- 100通/日
- 3,000通/月
- 1ドメイン認証

### 有料プラン（本番推奨）
- **Pro**: $20/月
  - 50,000通/月
  - 複数ドメイン
  - カスタムドメイン
  - 優先サポート

### アップグレード手順
1. Resend ダッシュボード → Settings → Billing
2. 「Upgrade to Pro」をクリック
3. クレジットカード情報を入力

---

## 📋 設定完了チェックリスト

- [ ] Resendアカウント作成完了
- [ ] API Key取得・保存完了
- [ ] hashpilot.biz ドメイン追加完了
- [ ] DNSレコード追加完了（TXT, CNAME）
- [ ] ドメイン認証完了（Verified）
- [ ] auth@hashpilot.biz 設定完了
- [ ] Supabase Edge FunctionにAPI Key設定完了
- [ ] テスト送信成功
- [ ] 必要に応じて有料プランにアップグレード

---

## 🔗 参考リンク

- Resend公式: https://resend.com
- Resendドキュメント: https://resend.com/docs
- ドメイン認証ガイド: https://resend.com/docs/dashboard/domains/introduction

---

## ⚠️ 重要な注意事項

1. **API Keyは絶対に公開しないこと**
   - GitHubにコミットしない
   - .env.local には含めない（Supabase環境変数のみ）

2. **DNS設定は慎重に**
   - 既存のレコードを上書きしない
   - 追加のみ行う

3. **送信制限に注意**
   - 無料プランは100通/日
   - 本番運用開始前に有料プランへ

---

**実施完了後、この手順書に記録:**

実施日: _______________
API Key保存場所: _______________
ドメイン認証状態: □ Verified □ Pending
備考: _______________
