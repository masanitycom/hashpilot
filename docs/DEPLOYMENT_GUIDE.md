# HASHPILOT システム修正・デプロイメントガイド

## 🎯 今回の修正内容

### 1. ブラウザキャッシュ問題の解決 ✅
**問題**: 削除されたユーザーでログイン後、同ブラウザで新規ユーザーが「ユーザーレコードが見つかりません」エラー

**修正内容**:
- セッション情報の強制リフレッシュ機能追加
- メールアドレス優先でのユーザー検索
- UUIDフォールバック検索
- エラー時の完全ログアウト処理

**影響**: 高齢者ユーザーの登録代行時の問題を解消

### 2. Edge Functions メール送信実装 ✅
**実装内容**:
- NFT承認時の自動メール送信
- HTML形式の詳細なメール内容
- 翌日利益開始の説明含む
- 承認情報の詳細記載

### 3. 翌日利益開始ルール完成 ✅
**実装済み**: 購入当日は日利対象外、翌日0:00以降から開始

## 🚀 デプロイメント手順

### ステップ1: フロントエンド変更のデプロイ
```bash
# Next.js アプリケーションをビルド・デプロイ
npm run build
# または Vercel/Netlify等にプッシュ
git add .
git commit -m "Fix browser cache login issue and implement Edge Functions email"
git push origin main
```

### ステップ2: Edge Functions デプロイ
```bash
# Supabase CLI でログイン（必要に応じて）
npx supabase login

# Edge Functions をデプロイ
npx supabase functions deploy send-approval-email

# 環境変数を設定
npx supabase secrets set RESEND_API_KEY=your_resend_api_key_here
```

### ステップ3: 環境変数設定

#### Supabase環境変数
```bash
# メール送信用APIキー（Resend）
RESEND_API_KEY=re_xxxxxxxxxx

# Supabase設定（既存）
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

#### Next.js環境変数（.env.local）
```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

### ステップ4: Resend アカウント設定

1. **Resend アカウント作成**: https://resend.com/
2. **APIキー取得**: ダッシュボード → API Keys → Create API Key
3. **ドメイン設定**: hashpilot.net ドメインを追加（任意）
4. **送信者設定**: noreply@hashpilot.net または既存ドメイン

### ステップ5: 動作確認

#### テスト項目
1. **ブラウザキャッシュ問題**:
   - 同じブラウザでユーザー削除→新規登録→ログイン
   - 「ユーザーレコードが見つかりません」エラーが解消されるか

2. **メール送信**:
   - NFT購入承認時にメールが送信されるか
   - メール内容が正しく表示されるか
   - システムログに記録されるか

3. **翌日利益開始**:
   - 今日購入したユーザーが日利対象外か
   - 昨日以前のユーザーが正常に日利を受け取るか

## 🔧 設定ファイル一覧

### 新規作成ファイル
```
supabase/
├── functions/
│   └── send-approval-email/
│       └── index.ts              # メール送信Edge Function
└── config.toml                   # Supabase設定

DEPLOYMENT_GUIDE.md               # このファイル
```

### 修正ファイル
```
app/
├── dashboard/page.tsx            # ブラウザキャッシュ問題修正
└── admin/purchases/page.tsx      # Edge Functions メール送信実装
```

## ⚠️ 重要な注意事項

### 1. メール送信制限
- Resend無料プランは月100通まで
- 必要に応じて有料プランにアップグレード

### 2. Edge Functions制限
- 実行時間: 最大60秒
- メモリ: 512MB
- 同時実行数に制限あり

### 3. セキュリティ
- APIキーは環境変数で管理
- 本番環境では適切な CORS 設定

### 4. 監視
- システムログでメール送信状況を監視
- Edge Functions のエラーログを確認

## 🧪 トラブルシューティング

### メール送信エラー
```bash
# ログ確認
npx supabase functions logs send-approval-email

# 環境変数確認
npx supabase secrets list
```

### ブラウザキャッシュ問題
- ユーザーに「Ctrl+F5」で強制リロードを案内
- 必要に応じてローカルストレージクリア

### Edge Functions エラー
```bash
# 関数の再デプロイ
npx supabase functions deploy send-approval-email --debug

# 環境変数の再設定
npx supabase secrets set RESEND_API_KEY=new_key
```

## 📊 成果予想

### ユーザー体験改善
- 登録代行時のエラー解消
- 承認通知の自動化
- より現実的な利益開始タイミング

### 運用負荷軽減
- 手動メール送信作業の削減
- サポート問い合わせの減少
- システムの安定性向上

---

**実装者**: Claude (Anthropic)  
**実装日**: 2025年1月11日  
**優先度**: 高（ユーザビリティ重要改善）