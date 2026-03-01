# HASHPILOT インフラ・環境設定

## 🚀 システム運用開始手順

### 環境変数の設定

**2つの独立した制御があります：**

1. **運用ステータスの制御**
   ```bash
   # .env.local ファイル
   NEXT_PUBLIC_SYSTEM_PREPARING=false  # 運用ステータス（準備中/待機中/運用中）を15日ルールに従って表示
   ```

2. **テスト注意書きの制御**
   ```bash
   # .env.local ファイル
   NEXT_PUBLIC_SHOW_TEST_NOTICE=true  # テスト運用中の注意書きを表示（10/14以降にfalseへ）
   ```

### デプロイ手順

1. **環境変数の更新**
   ```bash
   # .env.local ファイルを編集
   NEXT_PUBLIC_SYSTEM_PREPARING=false  # 運用ステータスを実際の15日ルールで表示
   NEXT_PUBLIC_SHOW_TEST_NOTICE=false  # 10/14以降にテスト注意書きを非表示
   ```

2. **ビルド＆デプロイ**
   ```bash
   npm run build
   # デプロイコマンド（環境に応じて）
   ```

3. **確認事項**
   - 運用ステータスが15日ルールに従って正しく表示される
   - テスト注意書きの表示/非表示が制御できる

---

## 🛠 開発環境

- Next.js 14 + TypeScript
- Supabase（データベース + RPC関数）
- Tailwind CSS（スタイリング）
- 段階的読み込み最適化（4ステージ）

---

## 📞 サポート

問題が発生した場合は、以下の情報と共に報告してください：
1. エラーメッセージ
2. 発生した操作
3. ユーザーID
4. ブラウザ情報

---

## 📧 システムメール機能（2025年10月11日実装）

### 概要
管理者からユーザーへのメール送信機能（一斉送信・個別送信）

### 機能
1. **一斉メール送信**
   - 全ユーザー
   - 承認済みユーザーのみ
   - 未承認ユーザーのみ

2. **個別メール送信**
   - 特定のユーザーIDを指定して送信

3. **メール送信履歴**
   - 管理者の送信履歴表示
   - 配信状況確認（送信成功/失敗/既読）

4. **ユーザー受信箱**
   - 受信メール一覧表示
   - 未読/既読管理
   - メール本文表示（HTML対応）

### データベーステーブル
- `system_emails`: メール本体
- `email_recipients`: 送信先・配信状況
- `email_templates`: メールテンプレート（将来拡張用）

### RPC関数
- `create_system_email()`: メール作成＆送信先登録
- `get_user_emails()`: ユーザーのメール一覧取得
- `mark_email_as_read()`: メールを既読にする
- `get_email_history()`: 管理者用メール送信履歴
- `get_email_delivery_details()`: メール配信詳細

### Edge Function
- `send-system-email`: Resend APIでメール送信処理

### 画面
- `/admin/emails`: 管理者メール送信画面（一斉・個別・履歴）
- `/inbox`: ユーザー受信箱

### メール送信フロー
1. 管理者が件名・本文・送信先を指定
2. `create_system_email()` でメール作成＆送信先登録
3. `send-system-email` Edge Functionでメール送信
4. 送信結果を `email_recipients` に記録

### セットアップ手順
1. SQLスクリプト実行:
   ```bash
   scripts/create-email-system-tables.sql
   scripts/create-email-rpc-functions.sql
   ```

2. Edge Functionデプロイ:
   ```bash
   npx supabase functions deploy send-system-email
   ```

3. Supabase環境変数設定:
   - `RESEND_API_KEY`: Resend APIキー

### 重要な注意事項
- メール送信にはResend APIを使用（`noreply@hashpilot.biz`）
- HTML形式のメール本文に対応
- 送信失敗時は `email_recipients.error_message` に記録
- RLS（Row Level Security）で権限制御済み

---

## 🔧 Staging環境（テスト環境）

### 概要
本番環境に影響を与えずにテストできる環境を提供します。

### 環境構成
- **本番環境**: https://hashpilot.net (mainブランチ)
- **テスト環境**: https://hashpilot-staging.vercel.app (stagingブランチ)

### ブランチ戦略
```
main ブランチ        → 本番環境
staging ブランチ     → テスト環境（ベーシック認証あり）
```

### 開発フロー

**1. テスト環境で開発・テスト**
```bash
git checkout staging
# コード修正...
git add .
git commit -m "新機能追加"
git push origin staging  # テスト環境に自動デプロイ
```

**2. テストOK → 本番環境に反映**
```bash
git checkout main
git merge staging
git push origin main     # 本番環境に自動デプロイ
```

### ベーシック認証
- **テスト環境のみ有効**
- ユーザー名: `admin` (環境変数 `BASIC_AUTH_USER`)
- パスワード: 環境変数 `BASIC_AUTH_PASSWORD` で設定

### Vercel環境変数設定

**Production（本番）:**
```env
NEXT_PUBLIC_ENV=production
NEXT_PUBLIC_SITE_URL=https://hashpilot.net
```

**Preview（テスト）:**
```env
NEXT_PUBLIC_ENV=staging
BASIC_AUTH_USER=admin
BASIC_AUTH_PASSWORD=(強力なパスワード)
NEXT_PUBLIC_SITE_URL=https://hashpilot-staging.vercel.app
```

### 詳細ドキュメント
完全なセットアップ手順は `STAGING_SETUP.md` を参照してください。

---

## 📧 システムメール送信の改善（2025年12月3日）

### バッチ送信機能

**問題:**
- 大量のメール（499件など）を一度に送信するとEdge Functionがタイムアウト（504エラー）
- 一部のメールしか送信されない

**解決策:**
- 50件ずつのバッチ処理を実装
- Edge Function側で`batch_size`パラメータをサポート（最大100件）
- フロントエンドで自動的にバッチを繰り返し送信

### 実装詳細

**Edge Function (`supabase/functions/send-system-email/index.ts`):**
```typescript
const { email_id, batch_size = 50 }: SendEmailRequest = await req.json()
const effectiveBatchSize = Math.min(batch_size, 100)

// pendingのみを取得（バッチサイズで制限）
.eq('email_id', email_id)
.eq('status', 'pending')
.limit(effectiveBatchSize)
```

**フロントエンド (`app/admin/emails/page.tsx`):**
```typescript
const resendPendingEmails = async (emailId: string, pendingCount: number) => {
  const BATCH_SIZE = 50
  while (true) {
    const { data: sendResult } = await supabase.functions.invoke("send-system-email", {
      body: { email_id: emailId, batch_size: BATCH_SIZE },
    })
    if (sendResult.sent_count === 0) break
    await new Promise(resolve => setTimeout(resolve, 1000)) // 1秒待機
  }
}
```

### 緊急停止方法

メール送信を緊急停止する場合：

```sql
-- 全ての未送信を停止
UPDATE email_recipients
SET status = 'failed',
    error_message = 'manually cancelled'
WHERE status = 'pending';
```

**注意:** `status`カラムは`pending`, `sent`, `failed`, `read`のみ許可。`cancelled`は使用不可。

### 再送信手順

停止した後に再送信したい場合：

```sql
-- 特定のメールの手動停止分をpendingに戻す
UPDATE email_recipients
SET status = 'pending',
    error_message = NULL
WHERE email_id = 'メールのUUID'
  AND status = 'failed'
  AND error_message = 'manually cancelled';
```

### 管理画面の再送信ボタン

- 各メールの履歴に「未送信 X件 再送信」ボタンを表示
- 選択したメールのみが黄色でハイライト表示（他は影響なし）
- 送信中はアイコンが回転し「送信中...」と表示
- 全てのボタンは送信中はdisabled（誤操作防止）

### RPC関数の修正

`get_email_history`関数で`pending_count`を追加：

```sql
-- scripts/FIX-get-email-history-correct-column.sql
CREATE OR REPLACE FUNCTION get_email_history(
  p_admin_email TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
  email_id UUID,
  subject TEXT,
  email_type TEXT,
  target_group TEXT,
  created_at TIMESTAMPTZ,
  total_recipients BIGINT,
  sent_count BIGINT,
  failed_count BIGINT,
  read_count BIGINT,
  pending_count BIGINT  -- 追加
)
...
WHERE se.sent_by = p_admin_email  -- created_byではなくsent_by
   OR p_admin_email IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
```

**注意:** `system_emails`テーブルには`created_by`カラムは存在せず、`sent_by`を使用する。

---

## 🔔 CoinW UIDポップアップ（2025年12月3日）

### 機能
- ダッシュボード表示時にCoinW UIDの確認を促すポップアップを表示
- 「次回から表示しない」チェックボックスで非表示設定可能
- `localStorage`に確認状態を保存（`coinw_uid_confirmed_{userId}`）

### 実装ファイル
- `components/coinw-uid-popup.tsx`
- `app/dashboard/page.tsx`（ポップアップの呼び出し）

### 注意事項
- ポップアップは`userData`スコープ内で呼び出す必要がある
- `CoinWAlert`コンポーネント内ではなく、メインの`OptimizedDashboardPage`内に配置

---

## 📊 運用実績サイト（yield.hashpilot.info）（2025年12月4日更新）

### 概要
外部公開用の運用実績表示サイト。Xserverでホスティング。

### ファイル構成
```
xserver/
├── xserver-yield.html       # 運用実績ページ（メイン）
├── xserver-faq.html         # FAQ
├── xserver-faq-redesign.html
├── xserver-guide.html       # ガイド
├── xserver-manual.html      # マニュアル
└── xserver-manual-redesign.html
```

### データ取得の仕組み
1. **Edge Function**: `get-daily-yields`
   - V1テーブル（`daily_yield_log`）: 11月のデータ（利率%）
   - V2テーブル（`daily_yield_log_v2`）: 12月以降のデータ（金額$）
   - 両方を統合して`profit_percentage`（ユーザー受取率%）を返す

2. **HTMLフロントエンド**: `xserver-yield.html`
   - 月選択プルダウン（全期間 / 月別）
   - 統計カード（レコード数、プラス/マイナス日数、期間合計、累積）
   - 日別テーブル（日付、ユーザー受取率%）

### データ形式の違い

**V1（11月、`daily_yield_log`）:**
- `user_rate`は既に%表示（例：0.099 = 0.099%）
- そのまま`profit_percentage`として使用

**V2（12月、`daily_yield_log_v2`）:**
- `profit_per_nft`（1NFTあたりの利益$）から計算
- `userRatePercent = (profit_per_nft / 1000) * 100`
- 例: profit_per_nft = $18.24 → 1.824%

### APIレスポンス例
```json
{
  "date": "2025-12-03",
  "profit_percentage": "1.824",
  "source": "v2"
},
{
  "date": "2025-11-30",
  "profit_percentage": "0.099",
  "source": "v1"
}
```

### デプロイ手順

**Edge Functionの更新（Supabase Dashboard）:**
1. https://supabase.com/dashboard にログイン
2. プロジェクト選択 → Edge Functions → `get-daily-yields`
3. コードを編集（`supabase/functions/get-daily-yields/index.ts`の内容をコピペ）
4. **Deploy**ボタンをクリック

**Edge Functionの更新（CLI）:**
```bash
npx supabase login
npx supabase link --project-ref soghqozaxfswtxxbgeer
npx supabase functions deploy get-daily-yields
```

**注意:** GitHubへのプッシュだけではEdge Functionはデプロイされない。手動でデプロイが必要。

**HTMLの更新:**
1. `xserver/xserver-yield.html`を編集
2. FTPでyield.hashpilot.infoにアップロード

### 機能
- **月選択プルダウン**: 全期間（11/1〜）/ 2025年12月 / 2025年11月...
- **統計カード**:
  - 総レコード数
  - プラス日数
  - マイナス日数
  - 選択期間合計（月別選択時はその月の合計）
  - TOTAL（11/1〜）（常に全期間の累積）
- **テーブル**: 日付とユーザー受取率(%)を表示

---

## 📬 管理者メール受信箱機能（2026年1月実装）

### 概要
`support@hashpilot.biz` 宛のメールを受信し、管理画面で閲覧・返信できる機能。

### 構成要素

**1. Cloudflare Email Worker**
- ファイル: `cloudflare-workers/email-receiver/worker.js`
- 役割: `support@hashpilot.biz` 宛メールを受信してSupabaseに保存
- UTF-8デコード対応（Base64, Quoted-Printable）
- 送信者名・メールアドレスの分離パース

**2. データベーステーブル**
- `received_emails`: 受信メール保存
  - `from_email`, `from_name`: 送信者情報
  - `subject`, `body_text`, `body_html`: メール内容
  - `is_read`, `is_replied`: ステータス管理

**3. RPC関数**
- `save_received_email()`: Workerからメール保存
- `get_received_emails()`: 管理者用受信一覧取得
- `mark_received_email_as_read()`: 既読設定

### 管理画面機能 (`/admin/emails`)

**受信箱タブ:**
- 受信メール一覧表示（未読/既読フィルター）
- メール詳細モーダル（HTML本文表示対応）
- 削除機能
- 返信機能

**送信元アドレス選択:**
- `noreply@hashpilot.biz`: システム通知用（返信不可）
- `support@hashpilot.biz`: サポート用（返信可能）

### 返信機能

**HTMLメール形式:**
```html
<div style="font-family: ...">
  <p>[返信本文]</p>
  <hr>
  <p style="color: #666;">日時 送信者 wrote:</p>
  <blockquote style="border-left: 3px solid #ccc;">
    [元メール本文]
  </blockquote>
  <hr>
  <p>--<br>HASH PILOT NFT<br>https://hashpilot.net</p>
</div>
```

**処理フロー:**
1. `system_emails` テーブルにHTML本文を保存
2. `email_recipients` に送信先を登録
3. `send-system-email` Edge Functionで送信
4. `received_emails` の `is_replied` を `true` に更新

### Cloudflare設定

**Email Routing:**
1. Cloudflare Dashboard → Email → Email Routing
2. Email Workers で `hashpilot-email-receiver` を作成
3. `support@hashpilot.biz` をWorkerにルーティング

**Worker環境変数:**
- `SUPABASE_URL`: Supabase URL
- `SUPABASE_SERVICE_KEY`: Service Role Key

### RLSポリシー

```sql
-- 管理者のみ受信メール閲覧可能
CREATE POLICY "管理者のみ受信メール閲覧可能" ON received_emails
FOR SELECT USING (
  is_admin((auth.jwt() ->> 'email'::text), auth.uid())
);

-- 管理者のみ受信メール削除可能
CREATE POLICY "管理者のみ受信メール削除可能" ON received_emails
FOR DELETE USING (
  is_admin((auth.jwt() ->> 'email'::text), auth.uid())
);
```

### 関連ファイル

- `cloudflare-workers/email-receiver/worker.js` - メール受信Worker
- `app/admin/emails/page.tsx` - 管理画面（送受信）
- `scripts/ADD-email-inbox-feature.sql` - DB設定スクリプト
- `supabase/functions/send-system-email/index.ts` - メール送信Edge Function

### トラブルシューティング

**文字化け:**
- Worker内の `decodeUtf8()`, `decodeQuotedPrintable()` でUTF-8デコード
- `Content-Transfer-Encoding` に応じて処理

**メールが届かない:**
1. Cloudflare Email Routingの設定確認
2. Worker環境変数（SUPABASE_URL, SUPABASE_SERVICE_KEY）確認
3. Workerログでエラー確認

**返信がプレーンテキスト:**
- HTMLをインラインスタイルで作成
- Edge Functionが `html` フィールドで送信

---

最終更新: 2026年3月1日
