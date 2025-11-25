# 本番環境 緊急修正手順

## 🚨 問題の概要

本番環境で以下の重大な問題が発見されました：

1. **運用開始前のユーザーへの誤配布**: `operation_start_date IS NULL` または `operation_start_date > 配布日` のユーザーに日利と紹介報酬が配布されている
2. **NFT承認フラグ未更新**: 91ユーザーが `has_approved_nft = false` または `operation_start_date = NULL` だが、実際にはNFTを保有している（$81,000の投資）
3. **V1システムの不備**: `process_daily_yield_with_cycles` 関数が `operation_start_date` をチェックしていない

## ⚠️ 緊急対応

### STEP 0: システム停止
**日利処理を一時停止してください**
- 管理画面で新しい日利を設定しない
- 問題が修正されるまで日利処理を実行しない

---

## 🔍 修正手順

### STEP 1: 誤配布データの確認

本番環境で以下のスクリプトを実行して、誤配布の詳細を確認します。

```bash
scripts/URGENT-CHECK-incorrect-profit-distribution.sql
```

**確認内容:**
- operation_start_date = NULL のユーザーへの配布
- operation_start_date > 配布日 のユーザーへの配布
- 誤配布の合計金額
- 日付別の誤配布金額
- 影響を受けたユーザーのリスト
- affiliate_cycleへの影響

**期待される結果:**
- 誤配布されたユーザー数
- 誤配布された金額（個人利益 + 紹介報酬）
- 各ユーザーの詳細データ

---

### STEP 2: V1システム関数の修正

本番環境の `process_daily_yield_with_cycles` 関数を修正します。

```bash
scripts/FIX-process-daily-yield-v1-operation-start-date.sql
```

**修正内容:**
- STEP 2（個人利益配布）: `operation_start_date IS NOT NULL AND operation_start_date <= p_date` をチェック
- STEP 3（紹介報酬配布）: 紹介される側と紹介者の両方の `operation_start_date` をチェック
- STEP 4（NFT自動付与）: `operation_start_date` をチェック

**実行方法:**
1. Supabaseダッシュボードにアクセス
2. SQL Editorを開く
3. スクリプト全体をコピー＆ペースト
4. 実行

**確認:**
```sql
SELECT '✅ 関数修正完了' as status;
```

---

### STEP 3: NFT承認フラグの修正

91ユーザーの `has_approved_nft` と `operation_start_date` を修正します。

```bash
scripts/FIX-production-has-approved-nft-bulk-update.sql
```

**実行手順:**

#### 3-1. 修正前の確認
STEP 1のクエリを実行して、修正対象のユーザー数と投資額を確認します。

#### 3-2. has_approved_nft の更新
STEP 2のコメントを外して実行します。

**期待される結果:**
- 91ユーザーの `has_approved_nft` が `true` に更新される

#### 3-3. operation_start_date の更新
STEP 3のコメントを外して実行します。

**期待される結果:**
- 91ユーザーの `operation_start_date` が設定される
- 各ユーザーの最初のNFT取得日から `calculate_operation_start_date()` 関数で計算

#### 3-4. 更新後の確認
STEP 4のクエリを実行して、修正が完了したことを確認します。

**期待される結果:**
- `has_approved_nft = false` だがNFTが存在するユーザー: **0件**
- `operation_start_date = NULL` だがNFTが存在するユーザー: **0件**

---

### STEP 4: 誤配布データの削除

⚠️ **この操作は取り消せません。必ずバックアップを取ってください。**

```bash
scripts/DELETE-incorrect-profit-distribution-CAREFUL.sql
```

**実行手順:**

#### 4-1. 削除前の確認
STEP 1とSTEP 2のクエリを実行して、削除対象のレコード数と金額を確認します。

#### 4-2. affiliate_cycleの調整額を確認
各ユーザーの `cum_usdt` と `available_usdt` からどれだけ差し引くべきかを確認します。

#### 4-3. 実際の削除
⚠️ **コメントを外す前に必ずバックアップを取ってください**

STEP 3のコメント `/* ... */` を外して実行します。

**処理内容:**
1. `affiliate_cycle.available_usdt` から個人利益分を差し引く
2. `affiliate_cycle.cum_usdt` から紹介報酬分を差し引く
3. `affiliate_cycle.phase` を再計算
4. `nft_daily_profit` から誤配布レコードを削除
5. `user_referral_profit` から誤配布レコードを削除

**デフォルトはROLLBACK:**
- 削除が正しく実行されたことを確認してから `COMMIT;` を実行
- 問題があれば `ROLLBACK;` で取り消し

#### 4-4. 削除後の確認
実行後の確認クエリで、誤配布レコードが0件になったことを確認します。

---

### STEP 5: システム再開

すべての修正が完了したら、日利処理を再開できます。

**再開前チェックリスト:**
- ✅ V1関数が修正された
- ✅ 91ユーザーのフラグが修正された
- ✅ 誤配布データが削除された
- ✅ 確認クエリで問題がないことを確認した

**再開方法:**
1. 管理画面 `/admin/yield` にアクセス
2. 最新の日付で日利を設定
3. ダッシュボードで正しく反映されているか確認

---

## 📊 修正後の検証

以下のスクリプトで本番環境の状態を確認します：

```bash
scripts/CHECK-production-v1-profit-analysis.sql
```

**確認項目:**
1. 全体の累積利益サマリー
2. 日付別の利益推移
3. マイナス個人利益の日にプラス紹介報酬が発生しているか
4. ユーザー別の累積利益
5. マイナス累積利益だがプラス紹介報酬のユーザー（正常な動作）
6. 紹介報酬の詳細
7. **運用開始前のユーザーに利益が発生しているか（0件であるべき）**
8. affiliate_cycleの異常値チェック

---

## 🔄 今後の対応

### V2システムへの移行
本番環境も将来的にV2システム（`process_daily_yield_v2`）に移行する予定です。

**V2システムの利点:**
- 累積ベースの計算（金額入力）
- より正確な分配計算
- 運用開始日チェックが組み込み済み

**移行スクリプト:**
- テスト環境で既にV2システムが稼働中
- `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql` で修正済み
- 本番環境への移行計画を作成予定

---

## 📝 修正履歴

### 2025年11月15日
- 本番環境で運用開始前のユーザーへの誤配布を発見
- 91ユーザーのNFT承認フラグ未更新を確認
- V1システムの関数修正スクリプトを作成
- 誤配布データ削除スクリプトを作成

---

## ⚠️ 重要な注意事項

1. **バックアップ**: すべての操作の前に必ずデータベースのバックアップを取ってください
2. **確認**: 各ステップの実行前に必ず確認クエリを実行してください
3. **段階的実行**: 一度にすべてを実行せず、1ステップずつ確認しながら進めてください
4. **ロールバック**: 問題があればすぐに `ROLLBACK;` を実行してください
5. **ログ**: すべての操作結果をログに記録してください

---

## 🆘 問題が発生した場合

1. **すぐに操作を停止**
2. **ROLLBACK を実行**（トランザクション中の場合）
3. **バックアップから復元**
4. **ログを確認して原因を特定**
5. **修正スクリプトを再確認**

---

最終更新: 2025年11月15日
