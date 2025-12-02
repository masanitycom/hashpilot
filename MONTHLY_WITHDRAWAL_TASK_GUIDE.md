# 月末出金タスクポップアップ表示ガイド

## 📋 概要

紹介報酬の手動計算完了後、ユーザーにタスクポップアップを表示させて出金申請を完了させる手順です。

---

## 🚀 手順（3ステップ）

### STEP 1: 紹介報酬の手動計算（既に完了）

✅ 11月分の紹介報酬を手動で計算・配布済み

---

### STEP 2: 出金レコード作成（これから実行）

Supabase SQL Editorで以下のスクリプトを実行：

```bash
scripts/QUICK-create-november-withdrawals.sql
```

**このスクリプトが行うこと：**
- `available_usdt >= $10` のユーザーに出金レコードを作成
- ステータス: `on_hold`（タスク未完了）
- 対象外: ペガサス出金制限中のユーザー
- 重複防止: 既に11月の出金レコードがあるユーザーは除外

**実行結果の例：**
```
✅ 出金レコード作成完了
作成件数: 298件
出金予定総額: $45,123.45
```

---

### STEP 3: ユーザーがタスクを完了

**ユーザー側の動作：**
1. ダッシュボードにアクセス
2. **タスクポップアップが自動表示される** 🎯
3. 簡単なアンケート（1問）に回答
4. 回答送信 → ステータスが `on_hold` → `pending` に変更
5. 「出金申請完了しました。5日以内に送金処理を行います。」と表示

**管理者側の動作：**
1. `/admin/withdrawals` で送金処理
2. 「完了済みにする」をクリック
3. ステータスが `pending` → `completed` に変更
4. `available_usdt` から出金額を減算

---

## 📊 動作確認

### タスクポップアップ対象ユーザー数を確認

```sql
SELECT
    COUNT(*) as タスク未完了ユーザー数
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
    AND status = 'on_hold'
    AND task_completed = false;
```

### 特定ユーザーの出金レコードを確認

```sql
SELECT
    mw.*,
    u.email
FROM monthly_withdrawals mw
INNER JOIN users u ON mw.user_id = u.user_id
WHERE mw.user_id = '177B83'
    AND mw.withdrawal_month = '2025-11-01';
```

---

## 🔧 トラブルシューティング

### Q1: タスクポップアップが表示されない

**確認項目：**
1. `monthly_withdrawals` にレコードが作成されているか
2. `status = 'on_hold'` になっているか
3. `task_completed = false` になっているか
4. ブラウザのキャッシュをクリア

### Q2: 同じユーザーに複数の出金レコードが作成された

**原因:** スクリプトを複数回実行した

**修正方法:**
```sql
-- 重複レコードを削除（最新のみ残す）
DELETE FROM monthly_withdrawals
WHERE id NOT IN (
    SELECT MAX(id)
    FROM monthly_withdrawals
    WHERE withdrawal_month = '2025-11-01'
    GROUP BY user_id
);
```

### Q3: ペガサス制限中のユーザーにレコードが作成された

**確認方法:**
```sql
SELECT
    mw.user_id,
    u.email,
    u.is_pegasus_exchange,
    u.pegasus_withdrawal_unlock_date,
    mw.total_amount
FROM monthly_withdrawals mw
INNER JOIN users u ON mw.user_id = u.user_id
WHERE mw.withdrawal_month = '2025-11-01'
    AND u.is_pegasus_exchange = true
    AND u.pegasus_withdrawal_unlock_date > CURRENT_DATE;
```

**修正方法:**
```sql
-- ペガサス制限中のユーザーのレコードを削除
DELETE FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
    AND user_id IN (
        SELECT user_id FROM users
        WHERE is_pegasus_exchange = true
            AND pegasus_withdrawal_unlock_date > CURRENT_DATE
    );
```

---

## 📁 関連ファイル

- **ワンステップ実行版:**
  - `scripts/QUICK-create-november-withdrawals.sql`

- **詳細確認版:**
  - `scripts/CREATE-manual-withdrawal-records.sql`

- **タスクポップアップUI:**
  - `components/reward-task-popup.tsx`
  - `app/dashboard/page.tsx` (line 109, 394, 419, 1079, 1091)

- **管理画面:**
  - `app/admin/withdrawals/page.tsx`

---

## 🎯 まとめ

**紹介報酬計算完了後の流れ：**

1. ✅ 紹介報酬を手動で計算・配布（完了）
2. 🔄 `QUICK-create-november-withdrawals.sql` を実行
3. ✅ ユーザーがダッシュボードにアクセス → タスクポップアップ表示
4. ✅ ユーザーがタスク完了 → 出金申請完了
5. ✅ 管理者が送金処理 → 完了

**重要ポイント：**
- スクリプトは**1回だけ**実行
- ユーザーは次回ログイン時に**自動的にポップアップが表示される**
- タスク完了まで**ポップアップは閉じられない**（必須）

---

最終更新: 2025年12月2日
