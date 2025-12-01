# 🚨 月末出金処理バグの緊急修正

## 問題の概要

**症状:**
- 2025年11月30日の日利処理後、月末出金レコードが **2件しか作成されていない**
- 本来は **58件** 作成されるべきだった
- **56名のユーザー** が出金処理から除外されている

**原因:**
```sql
-- process_monthly_withdrawals 関数の63行目
WHERE ac.available_usdt >= 100  -- ❌ 間違い！
```

本来は `>= 10` であるべきところが `>= 100` になっていた。

**影響範囲:**
- $10～$99 の出金対象ユーザー: **56名**
- 合計金額: 約 **$1,747**（$209 + $116 = $325が処理済み、残り$1,747が未処理）

---

## 修正手順

### STEP 0: 現状確認

```bash
# Supabase SQL Editorで実行
scripts/VERIFY-withdrawal-fix.sql
```

**確認すべきポイント:**
- 現在の出金レコード: 2件（DD525A: $209.01、93E0DC: $116.12）
- 本来の対象: 58件
- 欠落: 56件
- 欠落金額帯:
  - $10～$19: 約XX件
  - $20～$49: 約XX件
  - $50～$99: 約XX件
  - $100以上: 0件（既に処理済み）

---

### STEP 1: 関数を修正

```bash
# Supabase SQL Editorで実行
scripts/FIX-monthly-withdrawals-minimum-amount.sql
```

**実行内容:**
- `process_monthly_withdrawals` 関数の最低出金額を **100 → 10** に変更
- 実行完了メッセージが表示されることを確認

**期待される出力:**
```
✅ process_monthly_withdrawals 修正完了
変更内容:
  - 最低出金額: 100 USDT → 10 USDT
```

---

### STEP 2: 11月分を再処理

```bash
# Supabase SQL Editorで実行
scripts/REPROCESS-november-withdrawals.sql
```

**実行内容:**
1. 既存の2件の出金レコードを削除
2. 既存の2件のタスクレコードを削除
3. `process_monthly_withdrawals('2025-11-01')` を実行して再処理
4. 結果を詳細に表示

**期待される出力:**
```
✅ 11月の月末出金処理を再実行しました
処理結果:
  - 出金申請レコード: 58件
  - 総額: $1,956.88

処理詳細:
  - CoinW設定済み: XX件
  - BEP20設定済み: XX件
  - 送金先未設定: XX件
```

---

### STEP 3: 管理画面で確認

#### 3-1. 管理画面の出金一覧

**URL:** https://hashpilot.net/admin/withdrawals

**確認事項:**
- デフォルトで **2025-11** が選択されている
- **58件** のレコードが表示される
- 全てのステータスが `on_hold`（タスク未完了）
- `task_completed` が全て `false`

#### 3-2. ユーザーダッシュボード

**テストユーザー:** DD525A または 93E0DC（またはその他の出金対象ユーザー）

**確認事項:**
1. ダッシュボードを開く
2. **報酬タスクポップアップ** が自動表示される
3. ポップアップを閉じられない（必須タスク）
4. アンケート1問に回答して送信
5. ポップアップが閉じる
6. ステータスが `on_hold` → `pending` に変更される

**デバッグログ確認:**
```javascript
// ブラウザの開発者ツール → コンソール
[RewardTask] Checking for userId: DD525A
[RewardTask] Query result: { data: [...], error: null }
[RewardTask] Pending reward task found, showing popup
```

---

### STEP 4: 動作確認

#### 4-1. monthly_withdrawals テーブル

```sql
SELECT
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE status = 'on_hold') as on_hold,
    COUNT(*) FILTER (WHERE status = 'pending') as pending,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    COUNT(*) FILTER (WHERE task_completed = true) as task_completed,
    SUM(total_amount) as total_amount
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01';
```

**期待される結果:**
- total_count: 58
- on_hold: 58（タスク完了前）→ ユーザーがタスク完了すると減少
- pending: 0（タスク完了後に増加）
- completed: 0
- task_completed: 0（タスク完了後に増加）
- total_amount: $1,956.88

#### 4-2. monthly_reward_tasks テーブル

```sql
SELECT
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE is_completed = true) as completed,
    COUNT(*) FILTER (WHERE is_completed = false) as pending
FROM monthly_reward_tasks
WHERE year = 2025 AND month = 11;
```

**期待される結果:**
- total_count: 58
- completed: 0（ユーザーがタスク完了すると増加）
- pending: 58

---

## トラブルシューティング

### Q1: ポップアップが表示されない

**原因1: ブラウザキャッシュ**
```bash
# 解決方法
- Ctrl + Shift + R（強制リロード）
- ブラウザのキャッシュをクリア
```

**原因2: checkPendingRewardTask が実行されていない**
```javascript
// デバッグログを確認
console.log('[RewardTask] Checking for userId:', userId)
```

**原因3: クエリ条件が間違っている**
```sql
-- 手動で確認
SELECT * FROM monthly_withdrawals
WHERE user_id = 'DD525A'
  AND status = 'on_hold'
  AND task_completed = false;
```

---

### Q2: 再処理後も2件のまま

**原因: 関数が更新されていない**
```sql
-- 関数の定義を確認
SELECT prosrc
FROM pg_proc
WHERE proname = 'process_monthly_withdrawals';

-- "available_usdt >= 10" が含まれているか確認
```

**解決方法:**
```bash
# 関数を再度実行
scripts/FIX-monthly-withdrawals-minimum-amount.sql
```

---

### Q3: 一部のユーザーが除外されている

**原因: ペガサス制限**
```sql
-- ペガサス制限ユーザーを確認
SELECT
    u.user_id,
    u.email,
    ac.available_usdt,
    u.is_pegasus_exchange,
    u.pegasus_withdrawal_unlock_date
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND u.is_pegasus_exchange = true
  AND (
      u.pegasus_withdrawal_unlock_date IS NULL
      OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
  );
```

**これは正常な動作です。** ペガサス交換ユーザーは出金制限期間中は出金できません。

---

## 関連ファイル

### 修正スクリプト
- `scripts/FIX-monthly-withdrawals-minimum-amount.sql` - 関数修正
- `scripts/REPROCESS-november-withdrawals.sql` - 11月分再処理
- `scripts/VERIFY-withdrawal-fix.sql` - 現状確認

### フロントエンド
- `app/dashboard/page.tsx:729` - `checkPendingRewardTask` 関数
- `components/reward-task-popup.tsx` - ポップアップコンポーネント
- `app/admin/withdrawals/page.tsx:46` - 管理画面（デフォルト前月表示）

### データベース関数
- `process_monthly_withdrawals(DATE)` - 月末出金処理
- `complete_reward_task(VARCHAR, JSONB)` - タスク完了処理
- `complete_withdrawals_batch(INTEGER[])` - 一括送金完了処理

---

## チェックリスト

### 修正前
- [ ] `VERIFY-withdrawal-fix.sql` で現状確認
- [ ] 欠落ユーザー数と金額を記録

### 修正中
- [ ] `FIX-monthly-withdrawals-minimum-amount.sql` 実行
- [ ] 完了メッセージを確認
- [ ] `REPROCESS-november-withdrawals.sql` 実行
- [ ] 58件のレコードが作成されたことを確認

### 修正後
- [ ] 管理画面で58件表示されることを確認
- [ ] ユーザーダッシュボードでポップアップ表示を確認
- [ ] タスク完了フローをテスト
- [ ] `status` が `on_hold` → `pending` に変更されることを確認

---

## 今後の対策

### 1. テスト環境での事前確認
```bash
# テスト環境で必ず確認
# - 最低出金額が10 USDTであること
# - 少額ユーザーも含めて処理されること
```

### 2. 月末処理の自動テスト
```sql
-- 月末処理後に実行される検証クエリ
SELECT
    CASE
        WHEN COUNT(*) >= 50 THEN '✅ 正常（50件以上）'
        WHEN COUNT(*) >= 10 THEN '⚠️ 警告（10～49件）'
        ELSE '🚨 エラー（10件未満）'
    END as status,
    COUNT(*) as count,
    SUM(total_amount) as total
FROM monthly_withdrawals
WHERE withdrawal_month = DATE_TRUNC('month', CURRENT_DATE);
```

### 3. ドキュメント更新
- `CLAUDE.md` に月末出金処理の詳細を追加
- 最低出金額: **$10 USDT** を明記
- ペガサス制限ユーザーの除外ルールを明記

---

## まとめ

**バグの原因:**
- `process_monthly_withdrawals` 関数の `WHERE` 句が `>= 100` になっていた

**修正内容:**
- `>= 10` に変更

**影響:**
- 56名のユーザーが出金処理から除外されていた
- 修正後は全58名が処理される

**確認方法:**
1. 管理画面で58件表示
2. ユーザーダッシュボードでポップアップ表示
3. タスク完了フローが正常動作

---

最終更新: 2025年12月1日
