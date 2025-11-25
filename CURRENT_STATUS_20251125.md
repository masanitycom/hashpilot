# 現在の作業状況（2025-11-25 停電対策）

## 🔒 バックアップ情報

### 📌 バックアップブランチ
```bash
backup-before-referral-change-20251125
```

### 🔙 元に戻す方法
```bash
git checkout backup-before-referral-change-20251125
git push origin staging --force
```

---

## ✅ 完了した作業

### 最新コミット
- **コミットID**: `fdb10ba`
- **ブランチ**: `staging`
- **日時**: 2025-11-25
- **内容**: 紹介報酬カードを一時非表示

### 変更したファイル
1. **`app/dashboard/page.tsx`** (822行目)
   - 紹介報酬カードを非表示: `{false && ...}`
   - 個人利益カードはそのまま

2. **`components/referral-profit-card.tsx`**
   - 「月末集計後」メッセージに変更（既に適用済み）

3. **`scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql`**
   - 日次紹介報酬計算をコメントアウト（213-363行目）
   - マイナス日利でNFT自動付与されないように修正

---

## 🎯 現在の状態

### UI表示
- ✅ **個人利益カード**: 表示される
- ✅ **サイクルステータスカード**: 表示される
- ❌ **紹介報酬カード**: 非表示（`{false &&`で無効化）

### データベース
- ⚠️ **まだ変更していない**
- `user_referral_profit`: 既存データが残っている
- `monthly_referral_profit`: テーブル未作成

### 日利処理
- ⚠️ **V2関数はまだ旧バージョン**
- 日次紹介報酬計算は動作中（データベースに未適用）

---

## 📋 次にやること（停電後）

### STEP 1: Vercel デプロイ確認
```
https://hashpilot-staging.vercel.app/dashboard
```
- 紹介報酬カードが消えていることを確認
- 個人利益カードが表示されていることを確認

### STEP 2: データベーススクリプト適用
```bash
# Supabase SQL Editorで実行
1. scripts/CREATE-monthly-referral-profit-table.sql
2. scripts/CREATE-process-monthly-referral-profit.sql
3. scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql
```

### STEP 3: 既存データのクリア（オプション）
```sql
-- 既存の紹介報酬データを削除（慎重に！）
DELETE FROM user_referral_profit;
```

### STEP 4: 月別履歴セクション追加（後日）
- 前月確定報酬カード作成
- 月別利益履歴テーブル作成

---

## 🔧 トラブルシューティング

### UIが変わらない場合
1. Vercelのデプロイログを確認
2. ブラウザのキャッシュをクリア（Ctrl+Shift+R）
3. シークレットモードで確認

### 元に戻したい場合
```bash
# バックアップブランチに戻す
git checkout backup-before-referral-change-20251125
git push origin staging --force

# Vercelで再デプロイが自動実行される
```

### 停電から復帰したら
1. このファイル（CURRENT_STATUS_20251125.md）を開く
2. 「次にやること」から続きを実行
3. Vercelのデプロイ状況を確認

---

## 📂 重要なファイル

### ドキュメント
- `NEW_REFERRAL_SPEC.md`: 新仕様の詳細
- `WORK_IN_PROGRESS.md`: 作業進捗
- `NEXT_STEPS_SIMPLE.md`: 次の作業手順
- `CURRENT_STATUS_20251125.md`: このファイル（現在の状態）

### SQLスクリプト
- `scripts/CREATE-monthly-referral-profit-table.sql`: 月次テーブル
- `scripts/CREATE-process-monthly-referral-profit.sql`: 月次RPC関数
- `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql`: V2関数修正版

### バックアップ
- ブランチ: `backup-before-referral-change-20251125`
- コミット: `a4c2177`（変更前の状態）

---

## 💡 重要な注意事項

### システムへの影響
- ✅ **個人利益**: 影響なし（そのまま表示）
- ⚠️ **紹介報酬**: 一時的に非表示（ユーザーには見えない）
- ⚠️ **NFT自動付与**: まだ日次で動作中（月次に移行していない）

### ユーザーへの影響
- 紹介報酬が見えなくなる
- 個人利益は見える
- サイクル状況は見える

### データへの影響
- **まだない**（データベース未変更）
- 既存の紹介報酬データは残っている

---

## 📊 Git履歴

```
fdb10ba - feat: 紹介報酬カードを一時非表示（月次計算移行中）
a4c2177 - chore: force rebuild for UI changes
9192afb - chore: trigger Vercel deployment for UI changes
f169513 - feat: 紹介報酬を月次計算に完全移行
fd3c8fd - feat: 紹介報酬を月次計算に変更 + V2関数バグ修正
ac7da82 - feat: 日利削除機能を完全版に修正
```

---

## 🚨 緊急時の連絡先

- GitHub リポジトリ: https://github.com/masanitycom/hashpilot
- Vercel プロジェクト: https://vercel.com/masanitycom/hashpilot
- Supabase プロジェクト: soghqozaxfswtxxbgeer.supabase.co

---

最終更新: 2025-11-25 11:00
作成者: Claude Code
停電対策: UPS到着待ち
