# 作業進捗（2025-11-23）

## 🎯 作業内容
紹介報酬システムを日次計算から月次計算に変更

## ✅ 完了した作業（コミット: fd3c8fd）

### 1. 仕様書作成
- `NEW_REFERRAL_SPEC.md`: 月次紹介報酬システムの詳細仕様

### 2. データベーススクリプト作成
- `scripts/CREATE-monthly-referral-profit-table.sql`: 月次紹介報酬テーブル
- `scripts/CREATE-process-monthly-referral-profit.sql`: 月次計算RPC関数
- `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql`: V2関数にDROP FUNCTION追加

### 3. バグ修正
- V2関数: マイナス日利でNFT自動付与されないように修正
- `EMERGENCY_FIX_1109_AUTO_NFT.md`: 11/9バグ修正マニュアル

## 🔄 次にやること

### STEP 1: V2関数から紹介報酬計算を削除
ファイル: `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql`
- 209-355行目の紹介報酬計算部分をコメントアウト
- STEP 3全体を削除（日次では個人利益のみ配布）

### STEP 2: データベースに適用
```bash
# Supabase SQL Editorで実行
# 1. CREATE-monthly-referral-profit-table.sql
# 2. CREATE-process-monthly-referral-profit.sql
# 3. FIX-process-daily-yield-v2-FINAL-CORRECT.sql（修正版）
```

### STEP 3: ダッシュボードUI修正

#### A. 紹介報酬カードを「月末集計後」表示に変更
ファイル: `app/components/dashboard/referral-profit-card.tsx`
```tsx
// 修正: 累積表示 → 「月末集計後」メッセージ
<div>
  <p className="text-muted-foreground text-sm mb-2">
    ※ 紹介報酬は月末の集計後に表示されます
  </p>
  <div className="text-2xl font-bold text-muted-foreground">
    --
  </div>
</div>
```

#### B. 前月確定報酬カードを新規作成
ファイル: `app/components/dashboard/last-month-profit-card.tsx`（新規）
- 前月の個人利益と紹介報酬を表示
- `get_last_month_profit(user_id)` RPC関数を使用

#### C. 月別利益履歴セクションを新規作成
ファイル: `app/components/dashboard/monthly-profit-history.tsx`（新規）
- 月選択ドロップダウン
- 個人利益・紹介報酬・合計を表形式で表示
- `get_user_monthly_profit_history(user_id, year_month)` RPC関数を使用

#### D. ダッシュボードに追加
ファイル: `app/dashboard/page.tsx`
- LastMonthProfitCard を追加
- MonthlyProfitHistory を追加

### STEP 4: 管理画面に月次処理ボタン追加
ファイル: `app/admin/yield/page.tsx`
- 「月次紹介報酬を計算」ボタンを追加
- `process_monthly_referral_profit(year_month)` を呼び出し

## 📂 関連ファイル

### SQLスクリプト
- `scripts/CREATE-monthly-referral-profit-table.sql`
- `scripts/CREATE-process-monthly-referral-profit.sql`
- `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql`

### ドキュメント
- `NEW_REFERRAL_SPEC.md`
- `EMERGENCY_FIX_1109_AUTO_NFT.md`

### フロントエンド（修正予定）
- `app/components/dashboard/referral-profit-card.tsx`
- `app/components/dashboard/last-month-profit-card.tsx`（新規）
- `app/components/dashboard/monthly-profit-history.tsx`（新規）
- `app/dashboard/page.tsx`
- `app/admin/yield/page.tsx`

## 💡 停電したら
1. このファイル（WORK_IN_PROGRESS.md）を読む
2. `NEW_REFERRAL_SPEC.md` で仕様を確認
3. 「次にやること」から再開

---

最終更新: 2025-11-23 20:30
コミット: fd3c8fd
