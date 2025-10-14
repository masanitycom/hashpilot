# Cloudflare Worker デプロイ手順（超簡単）

## 🎯 この方法がベスト

- ✅ Xサーバー不要
- ✅ ネームサーバー問題なし
- ✅ SSL自動対応
- ✅ 5分で完了

---

## 📋 デプロイ手順

### ステップ1: Cloudflareダッシュボードにアクセス

1. https://dash.cloudflare.com/ にログイン

2. 左メニューから **Workers & Pages** をクリック

3. **Create application** → **Create Worker** をクリック

### ステップ2: Workerを作成

1. Worker名を入力（例: `hashpilot-yield`）

2. **Deploy** をクリック

3. **Edit code** をクリック

### ステップ3: コードを貼り付け

1. エディタに表示されている既存のコードを**全て削除**

2. `/mnt/d/HASHPILOT/cloudflare-worker-yield.js` の内容を**全てコピー**して貼り付け

3. 右上の **Save and Deploy** をクリック

### ステップ4: カスタムドメインを設定

1. Worker の設定画面に戻る

2. **Triggers** タブをクリック

3. **Custom Domains** セクションで **Add Custom Domain** をクリック

4. `hashpilot.biz` を入力して **Add Custom Domain**

5. 完了！

---

## ✅ 完了

数分後に以下のURLにアクセスできます：

- `https://hashpilot.biz/yield`
- `https://hashpilot.biz/yield/`

---

## 🔧 トラブルシューティング

### カスタムドメインが追加できない

Cloudflare DNS設定を確認：
- Aレコード（hashpilot.biz）が存在する必要があります
- プロキシ状態は**オレンジ雲（プロキシ済み）**にする

### 表示されない

1. ブラウザキャッシュをクリア（Ctrl+Shift+R）
2. 5-10分待つ（DNS伝播）
3. Workerのログを確認

---

## 📝 補足

### Workerの仕組み

```
訪問者 → Cloudflare Worker（hashpilot.biz/yield）→ HTMLを返す
                ↓
        Supabase Edge Function（日利データ取得）
```

### コスト

- **無料プラン**: 1日10万リクエストまで無料
- 日利ページなら十分すぎる

### 更新方法

コードを変更したい場合：
1. Workers & Pages → `hashpilot-yield` を選択
2. **Edit code** をクリック
3. コードを編集して **Save and Deploy**

---

最終更新: 2025年10月14日
