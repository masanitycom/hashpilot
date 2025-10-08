# 最近の変更による影響確認チェックリスト

## 実行済みのデータベース変更

### 1. fix-auto-purchase-cycle-display.sql
- [x] `purchases.cycle_number_at_purchase` カラム追加
- [x] 既存データへの連番設定
- [x] `get_auto_purchase_history` 関数の修正

### 2. add-cycle-number-to-auto-purchase.sql
- [ ] `process_daily_yield_with_cycles` 関数の修正

### 3. create-complete-withdrawal-function.sql
- [ ] `complete_withdrawal` 関数の作成
- [ ] `complete_withdrawals_batch` 関数の作成

## 確認が必要な機能

### 優先度: 高 🔴

#### 1. ダッシュボード表示
- [ ] https://hashpilot.net/dashboard にアクセス
- [ ] エラーなく表示される
- [ ] 自動NFT購入履歴が表示される
- [ ] サイクル番号が正しく表示される（25ではなく1, 2, 3...）

#### 2. 管理画面 - 出金管理
- [ ] https://hashpilot.net/admin/withdrawals にアクセス
- [ ] 出金一覧が表示される
- [ ] 出金を選択して「完了済みにする」をクリック
- [ ] エラーなく完了する
- [ ] `available_usdt` から出金額が減算される

#### 3. 管理画面 - 日利処理
- [ ] https://hashpilot.net/admin/yield にアクセス
- [ ] 日利設定が正常に表示される
- [ ] **テストモードで実行してみる**
- [ ] エラーなく完了する
- [ ] 戻り値が8列（月末出金処理件数を含む）

### 優先度: 中 🟡

#### 4. 月末タスクポップアップ
- [ ] 月末出金対象ユーザーとしてログイン
- [ ] タスクポップアップが表示される
- [ ] タスク完了できる
- [ ] 「出金申請完了しました。5日以内に送金処理を行います。」と表示される

#### 5. 出金ページ
- [ ] https://hashpilot.net/withdrawal にアクセス
- [ ] 送金方法の説明が「CoinW UIDに送金されます」となっている
- [ ] 最小出金額が$10と表示される
- [ ] 確認メールの説明が削除されている

### 優先度: 低 🟢

#### 6. サイトタイトル
- [ ] ブラウザタブのタイトルが「HASH PILOT NFT」になっている

## データベース整合性チェック

### SQL実行
```sql
-- Supabase SQL Editorで実行
-- scripts/verify-recent-changes-integrity.sql
```

### 確認ポイント
- [ ] `cycle_number_at_purchase` カラムが存在する
- [ ] 新規関数 `complete_withdrawal`, `complete_withdrawals_batch` が存在する
- [ ] `get_auto_purchase_history` 関数が正常に動作する
- [ ] 7E0A1Eの自動購入履歴にサイクル番号が設定されている
- [ ] `available_usdt`, `cum_usdt` にマイナス値がない

## 影響を受ける可能性のあるファイル

### データベース関数
- ✅ `get_auto_purchase_history` - 修正済み
- ⚠️ `process_daily_yield_with_cycles` - 未適用（要SQL実行）
- ✅ `complete_withdrawals_batch` - 新規作成（要SQL実行）

### フロントエンド
- ✅ `/components/auto-purchase-history.tsx` - 型修正済み
- ✅ `/components/reward-task-popup.tsx` - メッセージ追加済み
- ✅ `/app/admin/withdrawals/page.tsx` - RPC呼び出し変更済み
- ✅ `/app/withdrawal/page.tsx` - 説明文修正済み
- ✅ `/app/layout.tsx` - サイト名変更済み

## ロールバック手順（問題があった場合）

### データベース
```sql
-- cycle_number_at_purchase カラムを削除
ALTER TABLE purchases DROP COLUMN IF EXISTS cycle_number_at_purchase;

-- get_auto_purchase_history を元に戻す
-- （元のバージョンは scripts/implement-auto-nft-purchase.sql にある）

-- 新規関数を削除
DROP FUNCTION IF EXISTS complete_withdrawal(INTEGER);
DROP FUNCTION IF EXISTS complete_withdrawals_batch(INTEGER[]);
```

### コード
```bash
# 前のコミットに戻す
git revert HEAD~5..HEAD
git push origin main
```

## 今後の自動購入時の動作

次回の日利処理で自動NFT購入が発生した場合：
- `cycle_number_at_purchase` に現在のサイクル番号が記録される
- 自動購入履歴で正確なサイクル番号が表示される

## 備考

- テスト環境がないため、本番環境で慎重にテストする必要がある
- まずは管理画面でテストモードで実行してから本番実行
- 問題があればすぐにロールバック可能
