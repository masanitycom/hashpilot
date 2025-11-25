# 次の作業（シンプル版）

## 🎯 最小限の変更で完成させる

### 今すぐやること

#### 1. V2関数の紹介報酬計算を削除（213-359行目）
`scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql` の213-359行目を削除またはコメントアウト

**変更内容:**
```sql
-- ========================================
-- 紹介報酬を計算・配布（削除: 月次計算に変更）
-- ========================================
-- 注意: 紹介報酬は月末に process_monthly_referral_profit() で計算します
-- 日次では個人利益のみ配布

-- [213-359行目を削除]
```

#### 2. ダッシュボードUIの最小限の修正

**A. 紹介報酬カードを「月末集計後」に変更**

ファイル: `app/components/dashboard/referral-profit-card.tsx`

探す箇所: 累積紹介報酬を表示している部分

修正:
```tsx
<div className="text-sm text-muted-foreground mb-2">
  ※ 紹介報酬は月末の集計後に表示されます
</div>
<div className="text-2xl font-bold text-muted-foreground">
  計算中...
</div>
```

---

## 📋 完全版は後で実装

以下は後で実装（今は不要）：
- ❌ 前月確定報酬カード
- ❌ 月別利益履歴セクション
- ❌ 管理画面の月次処理ボタン

これらは月次計算を1回実行した後に追加すればOK

---

## 🚀 実装手順

### STEP 1: V2関数修正（5分）
1. `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql` を開く
2. 213-359行目を削除またはコメントアウト
3. ファイルを保存

### STEP 2: データベース適用（10分）
```bash
# Supabase SQL Editorで実行（staging環境）
# 1. CREATE-monthly-referral-profit-table.sql
# 2. CREATE-process-monthly-referral-profit.sql
# 3. FIX-process-daily-yield-v2-FINAL-CORRECT.sql（修正版）
```

### STEP 3: UIの最小修正（5分）
```bash
# 1. app/components/dashboard/referral-profit-card.tsx を開く
# 2. 累積表示部分を「月末集計後」メッセージに変更
# 3. 保存
```

### STEP 4: テスト（5分）
1. `npm run dev` で起動
2. ダッシュボードで紹介報酬が「計算中...」と表示されることを確認
3. 管理画面で日利設定が正常に動作することを確認

### STEP 5: コミット＆プッシュ
```bash
git add -A
git commit -m "feat: 紹介報酬を月次計算に変更（最小実装）"
git push origin staging
```

---

## ⏰ 所要時間: 約25分

停電したら、このファイルを見て続きから再開してください。

---

最終更新: 2025-11-23 20:40
