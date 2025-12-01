# メール配信問題の診断ガイド

作成日: 2025-12-01

## 🚨 現在の状況

- **新規登録の確認メール**: 届いていない
- **NFT承認メール**: 届いているか不明
- **システムメール（一括送信）**: ✅ 正常に動作中（11/2に216件送信成功）

---

## 📊 システムメールの送信履歴（確認済み）

最新の送信状況:
```
11/2: Hash Pilotスタート記念Zoom説明会
  - 499件中 216件送信成功、276件pending、0件失敗

10/16: VVIP bot 正式稼働開始
  - 78件送信成功（100%成功）
```

**結論**: Resend APIは正常に動作しており、`RESEND_API_KEY`も設定されている。

---

## 🔍 問題の原因（推測）

### 1. 新規登録の確認メール（Supabase Auth）

#### 症状
- ユーザーが新規登録しても確認メールが届かない
- メール認証ができないため、ログインできない

#### 原因の可能性

**A. Supabase Authのメール送信設定が未完了**
- Supabase Dashboard → Authentication → Email Templates → SMTP Settings
- デフォルトではSupabase内蔵のメールサーバーを使用（到達率が低い）
- カスタムSMTPが設定されていない可能性

**B. メール認証が無効化されている**
- Supabase Dashboard → Authentication → Providers → Email
- "Confirm email" が無効になっている可能性

**C. メールがスパムフォルダに入っている**
- Gmailの「迷惑メール」フォルダを確認
- 送信元が `noreply@supabase.co` または類似のアドレス

#### 確認手順

1. **Supabaseダッシュボードで確認**
   ```
   https://supabase.com/dashboard/project/YOUR_PROJECT_ID/auth/users

   新規登録したユーザーを検索:
   - Email Confirmed: false の場合、メールが届いていない
   - Last Sign In: Never の場合、認証未完了
   ```

2. **SMTP設定を確認**
   ```
   Supabase Dashboard → Settings → Authentication → SMTP Settings

   現在の設定:
   - Enable Custom SMTP: OFF の場合、Supabaseの内蔵サーバーを使用
   - Enable Custom SMTP: ON の場合、カスタムSMTP設定を確認
   ```

3. **メールテンプレートを確認**
   ```
   Supabase Dashboard → Authentication → Email Templates → Confirm signup

   送信元アドレスを確認:
   - From: noreply@mail.app.supabase.com（デフォルト）
   - または、カスタム設定済みのアドレス
   ```

#### 解決方法

**方法1: カスタムSMTP設定（推奨）**

ResendをカスタムSMTPとして使用:
```
Supabase Dashboard → Settings → Authentication → SMTP Settings

Enable Custom SMTP: ON
SMTP Host: smtp.resend.com
SMTP Port: 587
SMTP User: resend
SMTP Pass: (ResendのAPIキー re_xxxxxxxxx)
Sender email: auth@hashpilot.biz
Sender name: HASHPILOT
```

**方法2: メール認証を一時的に無効化（緊急対応）**

```
Supabase Dashboard → Authentication → Providers → Email
"Confirm email" のチェックを外す

⚠️ 注意: セキュリティリスクがあるため、本番環境では非推奨
```

**方法3: 手動でメール認証を完了**

```sql
-- 管理者が手動でユーザーを認証済みにする
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email = 'user@example.com';
```

---

### 2. NFT承認メール（Edge Function: send-approval-email）

#### 症状
- 管理者がNFT購入を承認しても、メールが届いているか不明

#### 原因の可能性

**A. Edge Functionのエラー**
- `RESEND_API_KEY` が設定されているが、呼び出しに失敗している
- `noreply@hashpilot.biz` が認証されていない

**B. 送信元アドレスの問題**
- コード (line 100): `from: 'HASHPILOT <noreply@hashpilot.biz>'`
- Resendで `noreply@hashpilot.biz` が認証済みか確認が必要

**C. Edge Functionが呼び出されていない**
- 管理画面のコードでエラーが発生している
- `supabase.functions.invoke('send-approval-email', ...)` が失敗している

#### 確認手順

1. **system_logsテーブルを確認**
   ```sql
   -- NFT承認メールの送信ログを確認
   SELECT
     log_type,
     operation,
     user_id,
     message,
     details,
     created_at
   FROM system_logs
   WHERE operation = 'send_approval_email'
   ORDER BY created_at DESC
   LIMIT 20;
   ```

   **期待される結果**:
   - `log_type = 'SUCCESS'`: メール送信成功
   - ログが存在しない: Edge Functionが呼び出されていない

2. **Supabase Edge Function ログを確認**
   ```
   Supabase Dashboard → Edge Functions → send-approval-email → Logs

   最近のログを確認:
   - エラーメッセージ
   - RESEND_API_KEY の設定状況
   - Resend APIのレスポンス
   ```

3. **Resendダッシュボードで確認**
   ```
   https://resend.com/emails

   送信履歴を確認:
   - From: noreply@hashpilot.biz のメールが存在するか
   - Status: Delivered / Bounced / Failed
   ```

4. **Resendのドメイン認証状態を確認**
   ```
   https://resend.com/domains

   hashpilot.biz の状態:
   - Status: Verified (緑色) → OK
   - Status: Pending (黄色) → DNS設定が未完了
   - Status: Failed (赤色) → DNS設定に問題

   noreply@hashpilot.biz の状態:
   - Verified Emails リストに存在するか確認
   ```

#### 解決方法

**方法1: Resendでnoreply@hashpilot.bizを認証**

```
Resend Dashboard → Domains → hashpilot.biz → Verified Emails
"Add Email" をクリック
Email: noreply@hashpilot.biz
保存
```

**方法2: 送信元アドレスを変更（認証済みアドレスを使用）**

システムメールで使用している送信元に変更:
```typescript
// supabase/functions/send-approval-email/index.ts
// line 100を変更
from: 'HASHPILOT <noreply@send.hashpilot.biz>',
```

**方法3: Edge Functionの再デプロイ**

設定変更後、Edge Functionを再デプロイ:
```bash
npx supabase functions deploy send-approval-email
```

---

## 🛠 今すぐ実行すべき確認コマンド

### 1. 新規登録メールの送信ログ確認

```sql
-- auth.usersテーブルで未認証ユーザーを確認
SELECT
  id,
  email,
  email_confirmed_at,
  created_at,
  last_sign_in_at
FROM auth.users
WHERE email_confirmed_at IS NULL
ORDER BY created_at DESC
LIMIT 20;
```

### 2. NFT承認メールの送信ログ確認

```sql
-- system_logsでメール送信履歴を確認
SELECT
  log_type,
  operation,
  user_id,
  message,
  details,
  created_at
FROM system_logs
WHERE operation = 'send_approval_email'
ORDER BY created_at DESC
LIMIT 20;
```

### 3. 最近のNFT承認処理を確認

```sql
-- 最近承認されたNFT購入を確認
SELECT
  p.id,
  p.user_id,
  u.email,
  p.admin_approved,
  p.approval_date,
  p.created_at
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
  AND p.approval_date IS NOT NULL
ORDER BY p.approval_date DESC
LIMIT 20;
```

---

## ✅ チェックリスト

### 新規登録メール
- [ ] Supabase Dashboard → Authentication → SMTP Settings を確認
- [ ] Enable Custom SMTP が ON になっているか
- [ ] auth.users テーブルで email_confirmed_at が NULL のユーザーを確認
- [ ] 新規登録テストを実行してメールが届くか確認

### NFT承認メール
- [ ] Resend Dashboard → Domains → hashpilot.biz が Verified か確認
- [ ] Resend Dashboard → noreply@hashpilot.biz が Verified Emails に存在するか確認
- [ ] system_logs テーブルに send_approval_email のログが存在するか確認
- [ ] Supabase Edge Functions → send-approval-email → Logs でエラーを確認
- [ ] Resend Dashboard → Emails で送信履歴を確認

---

## 📝 次のステップ

1. **上記のSQLコマンドを実行**して結果を報告
2. **Supabase Dashboard**でSMTP設定を確認
3. **Resend Dashboard**でドメイン認証状態を確認
4. **問題箇所が特定できたら、適切な解決方法を実施**

---

最終更新: 2025-12-01
