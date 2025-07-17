# 🚨 HASHPILOT 緊急利益計算ツール

本番環境での正確な利益計算のための外部Node.jsツール

## 🚀 緊急セットアップ

```bash
cd external-tools
npm install @supabase/supabase-js
```

## 📊 使用方法

### 基本実行
```bash
node profit-calculator.js 7A9637
```

### 特定日付での計算
```bash
node profit-calculator.js 7A9637 2025-07-16
```

### 環境変数設定
```bash
export SUPABASE_URL="https://soghqozaxfswtxxbgeer.supabase.co"
export SUPABASE_ANON_KEY="your_anon_key"
node profit-calculator.js 7A9637
```

## ⚡ 機能

### ✅ 完全独立計算
- SQLに依存しない
- Supabaseから直接データ取得
- 正確な紹介報酬計算

### 🎯 計算内容
1. **個人利益**: NFT数 × $1,000 × ユーザー利率
2. **Level1紹介報酬**: 直接紹介者利益 × 20%
3. **Level2紹介報酬**: 2段目紹介者利益 × 10%
4. **Level3紹介報酬**: 3段目紹介者利益 × 5%
5. **運用開始日チェック**: NFT承認+15日後から開始

### 📋 出力例
```json
{
  "userId": "7A9637",
  "yesterday": {
    "date": "2025-07-16",
    "personal": 0.720,
    "referral": {
      "level1": 0.144,
      "level2": 0.072,
      "level3": 0.036,
      "total": 0.252
    },
    "total": 0.972
  },
  "monthly": {
    "personal": 7.920,
    "total": 10.692
  }
}
```

## 🔧 トラブルシューティング

### 権限エラー
```bash
chmod +x profit-calculator.js
```

### 依存関係エラー
```bash
npm install --force
```

### データベース接続エラー
- SUPABASE_URLとSUPABASE_ANON_KEYを確認
- RLSポリシーを確認

## 🚨 緊急時の使用

本番環境でダッシュボード表示が正しくない場合：

1. このツールで正確な数値を確認
2. フロントエンドの計算ロジックと比較
3. 差異があれば、このツールの結果が正確

## 📞 サポート

本番環境での緊急事態対応のため、エラーは即座に報告してください。