# 月末出金システム移行計画

## ⚠️ 重要: 既存システムへの影響分析

### 作成したファイル

#### 1. SQLスクリプト
- `create-process-monthly-withdrawals.sql` - 新しい関数（既存に影響なし）
- `add-japan-timezone-helpers.sql` - ヘルパー関数（既存に影響なし）
- `migrate-to-monthly-withdrawal-only.sql` - 移行スクリプト（⚠️実行注意）

#### 2. フロントエンド
- `reward-task-popup.tsx` - タスクポップアップ修正
- `pending-withdrawal-card.tsx` - 自動表示ロジック追加

---

## 📋 変更内容の詳細

### ✅ 安全な変更（即座に適用可能）

#### 1. 新関数の追加
```sql
-- これらは新規関数なので既存システムに影響なし
- process_monthly_withdrawals(p_target_month)
- complete_reward_task(p_user_id, p_answers) -- ※既存を上書き
- 日本時間ヘルパー関数 (get_japan_date等)
```

**影響**: なし（新規関数）

**注意**: `complete_reward_task`は既存関数を上書きしますが、ロジックは互換性あり

---

### ⚠️ 注意が必要な変更

#### 1. タスクポップアップの閉じるボタン削除
**変更箇所**: `reward-task-popup.tsx`
- 閉じるボタン（X）を削除
- 「必須」バッジ追加

**影響**:
- ✅ 現在タスク未完了のユーザーはいない（月末のみ発生）
- ✅ 既存のタスク完了済みユーザーには影響なし
- ⚠️ 次回月末処理から強制モーダルになる

#### 2. タスクの自動表示
**変更箇所**: `pending-withdrawal-card.tsx`
- `task_required=true && !task_completed`の場合、自動でポップアップ表示

**影響**:
- ✅ 現在該当ユーザーなし（月末処理後のみ発生）
- ⚠️ 月末処理実行後、該当ユーザーに即座にポップアップ表示

---

### 🚫 削除が必要な機能

#### 個別出金申請システム (`withdrawal_requests`)
- テーブル: `withdrawal_requests`
- 関数: `create_withdrawal_request`, `process_withdrawal_request`等

**⚠️ 重要確認事項**:
1. 現在保留中の個別出金申請はありますか？
2. ユーザーが個別出金申請機能を使っていますか？
3. フロントエンドで個別出金申請UIがありますか？

**安全な削除手順**:
```sql
-- STEP 1: 保留中の申請を確認
SELECT * FROM withdrawal_requests WHERE status = 'pending';

-- STEP 2: 全申請を確認
SELECT COUNT(*), status FROM withdrawal_requests GROUP BY status;

-- STEP 3: 問題なければ削除（慎重に！）
-- DROP TABLE withdrawal_requests CASCADE;
```

---

## 🔄 推奨移行手順

### フェーズ1: 準備（今すぐ実行可能）

```bash
# 1. 日本時間ヘルパー関数を追加（既存に影響なし）
psql $DATABASE_URL -f scripts/add-japan-timezone-helpers.sql

# 2. 新しい月末出金関数を追加（既存に影響なし）
psql $DATABASE_URL -f scripts/create-process-monthly-withdrawals.sql
```

**確認**:
```sql
-- 関数が正しく作成されたか確認
SELECT routine_name FROM information_schema.routines
WHERE routine_name IN ('process_monthly_withdrawals', 'get_japan_date', 'is_month_end');
```

---

### フェーズ2: フロントエンド更新（慎重に）

```bash
# 1. ビルドして構文エラーがないか確認
npm run build

# 2. 問題なければデプロイ
# （デプロイ方法は環境による）
```

**確認ポイント**:
- タスクポップアップが正常に表示されるか
- 既存の出金状況カードが正常に表示されるか

---

### フェーズ3: 個別出金システム削除（⚠️最も慎重に）

**事前確認**:
```sql
-- withdrawal_requests の使用状況確認
SELECT
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE status = 'pending') as pending,
    COUNT(*) FILTER (WHERE status = 'approved') as approved
FROM withdrawal_requests;
```

**削除実行** (保留中の申請がないことを確認後):
```sql
-- 関数削除
DROP FUNCTION IF EXISTS create_withdrawal_request(TEXT, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS process_withdrawal_request(UUID, TEXT, TEXT, TEXT, TEXT);

-- テーブル削除（必要に応じて）
-- DROP TABLE IF EXISTS withdrawal_requests CASCADE;
```

---

## 🧪 テスト手順

### 1. 月末処理のテスト実行

```sql
-- テスト用ユーザーの残高を100以上に設定
UPDATE affiliate_cycle
SET available_usdt = 150
WHERE user_id = 'TEST_USER_ID';

-- 月末処理を手動実行
SELECT * FROM process_monthly_withdrawals('2025-10-01'::DATE);

-- 結果確認
SELECT * FROM monthly_withdrawals WHERE user_id = 'TEST_USER_ID';
SELECT * FROM monthly_reward_tasks WHERE user_id = 'TEST_USER_ID';
```

### 2. タスク完了のテスト

```sql
-- タスク完了を実行
SELECT complete_reward_task('TEST_USER_ID', '[{"question_id": "xxx", "answer": "A"}]'::JSONB);

-- ステータスが pending に変わったか確認
SELECT status, task_completed FROM monthly_withdrawals WHERE user_id = 'TEST_USER_ID';
```

### 3. ペガサス交換ユーザーの除外確認

```sql
-- ペガサス交換ユーザーを設定
UPDATE users
SET is_pegasus_exchange = true,
    pegasus_withdrawal_unlock_date = '2025-12-31'
WHERE user_id = 'PEGASUS_USER';

-- 残高を設定
UPDATE affiliate_cycle
SET available_usdt = 150
WHERE user_id = 'PEGASUS_USER';

-- 月末処理実行
SELECT * FROM process_monthly_withdrawals('2025-10-01'::DATE);

-- ペガサスユーザーが除外されているか確認
SELECT * FROM monthly_withdrawals WHERE user_id = 'PEGASUS_USER';
-- ↑ レコードが作成されていないはず
```

---

## 📊 ロールバック手順

### フロントエンドのロールバック

```bash
# Git で変更を戻す
git checkout HEAD -- components/reward-task-popup.tsx
git checkout HEAD -- components/pending-withdrawal-card.tsx

# 再ビルド・再デプロイ
npm run build
```

### データベースのロールバック

```sql
-- 新関数を削除（必要に応じて）
DROP FUNCTION IF EXISTS process_monthly_withdrawals(DATE);

-- 日本時間ヘルパーを削除
DROP FUNCTION IF EXISTS get_japan_date();
DROP FUNCTION IF EXISTS get_japan_now();
-- 等々...
```

---

## ✅ チェックリスト

- [ ] 日本時間ヘルパー関数を適用
- [ ] 新しい月末出金関数を適用
- [ ] 関数が正しく作成されたか確認
- [ ] フロントエンドをビルド・確認
- [ ] withdrawal_requests の使用状況を確認
- [ ] テスト環境で月末処理を実行
- [ ] タスク完了フローをテスト
- [ ] ペガサス除外ロジックをテスト
- [ ] 本番環境にデプロイ
- [ ] 個別出金システムの削除を検討

---

## 💡 推奨事項

1. **まず日本時間ヘルパー関数だけ適用** - 既存に影響なし
2. **月末出金関数を追加** - 既存に影響なし
3. **フロントエンドは月末前に更新** - 月末処理前に準備
4. **個別出金システムは最後に削除** - 使われていないことを確認後

---

最終更新: 2025-10-08
