# 日利データAPI - セットアップガイド

## 概要

hashpilot.netの日利データを外部サイト（hashpilot.biz/yield）に表示するためのAPI。

---

## 📋 セットアップ手順

### 1. Edge Functionのデプロイ

```bash
# Supabase CLIでログイン
npx supabase login

# プロジェクトにリンク
npx supabase link --project-ref YOUR_PROJECT_REF

# Edge Functionをデプロイ
npx supabase functions deploy get-daily-yields
```

### 2. デプロイ後のURL確認

デプロイが完了すると、以下のようなURLが表示されます：
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-daily-yields
```

### 3. HTMLファイルの設定

`public/examples/yield-display-example.html` の以下の部分を編集：

```javascript
// ⚠️ この部分をあなたのURLに変更
const API_URL = 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-daily-yields';
```

実際のURLに置き換えてください。

### 4. hashpilot.biz へのデプロイ

1. `yield-display-example.html` を hashpilot.biz サーバーの `/yield/index.html` としてアップロード
2. ブラウザで `https://hashpilot.biz/yield` にアクセス

---

## 🔌 API エンドポイント

### 基本エンドポイント
```
GET https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-daily-yields
```

### クエリパラメータ（オプション）

| パラメータ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| `limit` | number | 30 | 取得件数 |
| `start_date` | string | - | 開始日（YYYY-MM-DD） |
| `end_date` | string | - | 終了日（YYYY-MM-DD） |

### 使用例

```javascript
// 最新30件を取得
fetch('https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-daily-yields')

// 最新50件を取得
fetch('https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-daily-yields?limit=50')

// 特定期間を取得
fetch('https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-daily-yields?start_date=2025-10-01&end_date=2025-10-31')
```

---

## 📊 レスポンス形式

### 成功時

```json
{
  "success": true,
  "data": [
    {
      "date": "2025-10-14",
      "yield_rate": 1.6,
      "user_rate": 0.672,
      "margin_rate": 0.3,
      "profit_percentage": "0.672",
      "created_at": "2025-10-14T10:30:00.000Z"
    },
    {
      "date": "2025-10-13",
      "yield_rate": -0.2,
      "user_rate": -0.156,
      "margin_rate": 0.3,
      "profit_percentage": "-0.156",
      "created_at": "2025-10-13T10:30:00.000Z"
    }
  ],
  "count": 2
}
```

### エラー時

```json
{
  "success": false,
  "error": "エラーメッセージ"
}
```

---

## 🎨 表示項目

HTMLページには以下の情報が表示されます：

### 統計情報
- 総レコード数
- プラス日数
- マイナス日数
- 平均日利率
- 平均ユーザー受取率

### テーブル
- 日付
- 日利率 (%)
- ユーザー受取率 (%)
- 増加率 (%)

---

## 🔒 セキュリティ

### CORS設定

Edge FunctionではCORSヘッダーを設定済み：
```typescript
'Access-Control-Allow-Origin': '*'
```

本番環境では特定のドメインのみ許可することを推奨：
```typescript
'Access-Control-Allow-Origin': 'https://hashpilot.biz'
```

### 認証（オプション）

APIキーによる認証を追加する場合：

```typescript
// Edge Function側
const apiKey = req.headers.get('X-API-Key')
if (apiKey !== Deno.env.get('CUSTOM_API_KEY')) {
  return new Response('Unauthorized', { status: 401 })
}
```

```javascript
// クライアント側
fetch(API_URL, {
  headers: {
    'X-API-Key': 'your-secret-key'
  }
})
```

---

## 🚀 カスタマイズ

### デザインの変更

`yield-display-example.html` のCSSセクションを編集してください。

### 自動更新の有効化

HTMLファイルの最下部のコメントを解除：

```javascript
// 30秒ごとに自動更新
setInterval(loadYieldData, 30000);
```

### 追加の統計情報

`displayStats()` 関数に追加：

```javascript
const maxYield = Math.max(...data.map(d => d.yield_rate));
const minYield = Math.min(...data.map(d => d.yield_rate));
```

---

## 📝 ファイル構成

```
/mnt/d/HASHPILOT/
├── supabase/functions/get-daily-yields/
│   └── index.ts                           # Edge Function
├── public/examples/
│   └── yield-display-example.html         # サンプルHTMLページ
└── docs/
    └── YIELD-API-SETUP.md                 # このドキュメント
```

---

## 🐛 トラブルシューティング

### Edge Functionがデプロイできない

```bash
# Supabase CLIを最新版に更新
npm install -g supabase

# 再度デプロイ
npx supabase functions deploy get-daily-yields
```

### CORSエラーが発生する

Edge FunctionのCORS設定を確認：
- `OPTIONS`リクエストに対応しているか
- `Access-Control-Allow-Origin`ヘッダーが正しいか

### データが表示されない

1. ブラウザの開発者ツール（F12）でConsoleを確認
2. NetworkタブでAPIリクエストを確認
3. Edge FunctionのログをSupabaseダッシュボードで確認

---

## 📞 サポート

問題が発生した場合は、以下を確認してください：
1. Edge FunctionのURL
2. daily_yield_logテーブルにデータがあるか
3. ブラウザのコンソールエラー

---

最終更新: 2025年10月14日
