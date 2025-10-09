# HASHPILOT システム管理ガイド

## 🚀 システム運用開始手順

### 環境変数の設定

**2つの独立した制御があります：**

1. **運用ステータスの制御**
   ```bash
   # .env.local ファイル
   NEXT_PUBLIC_SYSTEM_PREPARING=false  # 運用ステータス（準備中/待機中/運用中）を15日ルールに従って表示
   ```

2. **テスト注意書きの制御**
   ```bash
   # .env.local ファイル
   NEXT_PUBLIC_SHOW_TEST_NOTICE=true  # テスト運用中の注意書きを表示（10/14以降にfalseへ）
   ```

### デプロイ手順

1. **環境変数の更新**
   ```bash
   # .env.local ファイルを編集
   NEXT_PUBLIC_SYSTEM_PREPARING=false  # 運用ステータスを実際の15日ルールで表示
   NEXT_PUBLIC_SHOW_TEST_NOTICE=false  # 10/14以降にテスト注意書きを非表示
   ```

2. **ビルド＆デプロイ**
   ```bash
   npm run build
   # デプロイコマンド（環境に応じて）
   ```

3. **確認事項**
   - 運用ステータスが15日ルールに従って正しく表示される
   - テスト注意書きの表示/非表示が制御できる

---

## 📊 Level 4+紹介者計算の仕様

### 現在の正確な数値
- **Level 4+紹介者数: 89人**（2025年1月時点）
- 160人と表示されていた理由: 以前は`total_purchases = 0`のユーザーも含めて計算していた

### 計算ロジック
```javascript
// app/dashboard/page.tsx
1. usersテーブルから total_purchases > 0 のユーザーのみ取得
2. referrer_user_id でレベル別に分類
3. Level 4+を最大500レベルまで計算（実際の深度は18レベル）
4. allProcessedIds で重複チェック済み
```

### 重要な仕様
- **人数カウント**: 各ユーザーは1回だけカウント（user_idの重複チェック済み）
- **金額反映**: `Math.floor(total_purchases / 1100) * 1000` で計算
- **複数NFT購入**: 人数は増えず、金額のみ増加

### 検証済み事項
✅ 新規登録ユーザーは total_purchases = 0 なので影響なし  
✅ NFT購入申請の重複があっても正しく処理  
✅ 管理者承認済みのユーザーのみカウント  
✅ 4つの異なる計算方法で全て89人に一致することを確認

---

## 🎯 運用ステータス表示の仕様

### 表示パターン

1. **システム準備中**（NEXT_PUBLIC_SYSTEM_PREPARING=true）
   - バッジ: 🔵 システム準備中
   - 説明文: 「※ 現在メインシステムの準備を進めています。15日ルールは適用されますが、実際の運用開始はシステム準備完了後となります。」
   
2. **運用待機中**（15日未経過）
   - バッジ: 🟠 運用待機中
   - 残り日数表示: (あとX日)

3. **運用中**（15日経過済み & NEXT_PUBLIC_SYSTEM_PREPARING=false）
   - バッジ: 🟢 運用中
   - 運用開始日表示

### 運用開始日ルール（2025年10月更新）

**新ルール:**
- **毎月5日までに購入** → 当月15日より運用開始
- **毎月20日までに購入** → 翌月1日より運用開始
- **毎月20日より後に購入** → 翌月1日より運用開始

**実装:**
- `calculate_operation_start_date()`関数で自動計算
- `users.operation_start_date`カラムに保存
- 日利処理と紹介報酬計算で運用開始日をチェック
- 運用開始前のユーザーは日利・紹介報酬の対象外

**フロントエンドの運用開始日チェック:**
- `referral-profit-card.tsx`: 紹介報酬計算時に`operation_start_date`をチェック
- `total-profit-card.tsx`: 合計利益計算時に`operation_start_date`をチェック
- `monthly-profit-card.tsx`: 月次利益計算時に`operation_start_date`をチェック
- 条件: `operation_start_date IS NOT NULL AND operation_start_date <= 今日`

**旧ルール（廃止）:**
- ~~承認日から15日後に運用開始~~ → 2025年10月に新ルールへ変更

---

## 🔧 トラブルシューティング

### Level 4+の人数が想定と異なる場合
```bash
# 検証スクリプトを実行
node comprehensive_referral_verification.js
```

### 運用ステータスが正しく表示されない場合
1. `.env.local` の `NEXT_PUBLIC_SYSTEM_PREPARING` を確認
2. ブラウザのキャッシュをクリア
3. `npm run dev` で再起動

---

## 📝 重要な注意事項

1. **total_purchases の管理**
   - 管理者が手動で更新する必要がある
   - 購入承認時に必ず更新すること
   - 複数回の購入承認がある場合は合計額で更新

2. **データベースフィールド**
   - `users.nft_receive_address`（`nft_address`ではない）
   - `users.total_purchases` > 0 が投資済みユーザーの条件

3. **紹介レベルの制限**
   - 最大500レベルまで計算（実際は18レベル程度）
   - 無限ループ防止のための安全装置

---

## 📈 システム統計（2025年1月時点）

- 全ユーザー数: 189人
- 投資済みユーザー: 110人
- 複数NFT購入者: 7人
- 最大NFT購入数: 21個（$23,100）
- 紹介ツリー最大深度: 18レベル

---

## 💰 日利管理のマージン計算仕様（2025年8月24日更新）

### 基本ルール
- **プラス利益時**: マージン30%を引く（会社が取る）
- **マイナス利益時**: マージン30%を戻す（会社が補填する）

### 計算式
#### プラス利益時（日利率 > 0）
```
ユーザー受取率 = 日利率 × (1 - 0.30) × 0.6
例: +1.6% → 1.6% × 0.7 × 0.6 = 0.672%
```

#### マイナス利益時（日利率 < 0）
```
ユーザー受取率 = 日利率 × (1 + 0.30) × 0.6
例: -0.2% → -0.2% × 1.3 × 0.6 = -0.156%
```

### なぜこの計算方式？
月間累計で正しいマージン30%になるようにするため：
```
例：+$500, +$500, +$500, -$500 の場合
- 日次マージン: $150 + $150 + $150 - $150 = $300
- 月間累計利益: $1,000
- マージン率: $300 ÷ $1,000 = 30% ✅
```

### 重要な変更履歴
- 2025/08/24: マイナス時のマージン計算を修正（0% → 30%補填）
- 月末調整処理は不要（日次処理で自動的に正しくなる）

---

## 🔄 NFTサイクルシステム（2025年10月7日更新）

### 基本仕様
- **サイクル計算対象**: 紹介報酬のみ（個人利益は含めない）
- **NFT自動付与**: 紹介報酬が2200ドル到達時に自動的にNFTが付与される
- **フェーズ管理**:
  - **USDTフェーズ**: 紹介報酬 < 1100ドル（即時受取可能）
  - **HOLDフェーズ**: 紹介報酬 >= 1100ドル（次のNFT付与待ち、出金不可）
  - **NFT付与**: 紹介報酬 >= 2200ドル（自動NFT付与 + 1100ドル受取可能）

### 重要な注意事項
1. **個人利益（日利）はサイクルに含まれない**
   - 個人利益は`available_usdt`に直接加算される
   - サイクル計算は紹介報酬のみで行われる

2. **二重払い防止**
   - HOLDフェーズ中（cum_usdt >= 1100）の金額は出金不可
   - 次のNFT購入に使用される予定のため

3. **自動NFT付与の動作**
   - `cum_usdt >= 2200`到達時に`process_daily_yield_with_cycles`関数で自動処理
   - `nft_master`テーブルに実際のNFTレコードが作成される
   - `purchases`テーブルに`is_auto_purchase = true`のレコードが作成される

### データベーステーブル
- `affiliate_cycle.cum_usdt`: 紹介報酬の累積額
- `affiliate_cycle.available_usdt`: 即時受取可能な金額（個人利益 + NFT付与時の1100ドル）
- `affiliate_cycle.phase`: 現在のフェーズ（USDT/HOLD）
- `affiliate_cycle.auto_nft_count`: 自動付与されたNFT数
- `affiliate_cycle.manual_nft_count`: 手動購入したNFT数

---

## 💸 月末自動出金システム（2025年10月実装）

### 基本仕様
- **実行タイミング**: 月末の日利処理後に自動実行
- **対象ユーザー**: `available_usdt >= 10`のユーザー
- **初期ステータス**: `on_hold`（タスク未完了）
- **送金方法**: CoinW UIDのみ（BEP20アドレスは未対応）

### 処理フロー
1. **月末検知**: `is_month_end()`関数で日本時間の月末を判定
2. **出金申請作成**:
   - `monthly_withdrawals`テーブルにレコード作成
   - `status = 'on_hold'`, `task_completed = false`
3. **タスクポップアップ表示**:
   - ユーザーに1問のアンケートタスクを表示
   - タスク完了まで閉じられない（必須）
4. **タスク完了**:
   - `status`が`on_hold` → `pending`に変更
   - `task_completed = true`
5. **管理者送金**:
   - 管理画面で「完了済みにする」をクリック
   - `complete_withdrawals_batch()`関数で処理
   - `available_usdt`から出金額を減算
   - `status`が`pending` → `completed`に変更

### 重要な注意事項
1. **ペガサス交換ユーザー**: 出金制限期間中は自動出金の対象外
2. **最小出金額**: $10以上
3. **メール通知**: 未実装（将来実装予定）
4. **タスク問題**: 20問からランダムに1問表示

### データベーステーブル
- `monthly_withdrawals`: 月末出金申請レコード
  - `status`: `on_hold` / `pending` / `completed`
  - `task_completed`: タスク完了フラグ
  - `withdrawal_method`: `coinw` のみ
  - `withdrawal_address`: CoinW UID
- `monthly_reward_tasks`: タスク完了記録
  - `is_completed`: タスク完了フラグ
  - `answers`: 回答内容（JSONB）

### 関連関数
- `process_monthly_withdrawals(DATE)`: 月末出金処理
- `complete_reward_task(VARCHAR, JSONB)`: タスク完了処理
- `complete_withdrawals_batch(INTEGER[])`: 一括出金完了処理

---

## 🔢 自動NFT購入履歴のサイクル番号（2025年10月実装）

### 仕様
- **サイクル番号記録**: 購入時点のサイクル番号を記録
- **表示**: ダッシュボードの自動NFT購入履歴で表示
- **目的**: 各購入が何回目のサイクルで行われたかを明確化

### 実装
- `purchases.cycle_number_at_purchase`カラムに記録
- `process_daily_yield_with_cycles()`関数で自動記録
- `get_auto_purchase_history()`関数で取得・表示

### データ型
- `purchase_date`: TIMESTAMPTZ（タイムゾーン付き）
- `amount_usd`: NUMERIC（数値型）
- `cycle_number`: INTEGER（購入時のサイクル番号）

---

## 🏷️ サイト情報

### サイト名
- **現在**: HASH PILOT NFT
- **以前**: HASH PILOT Database（2025年10月変更）

### 表示場所
- ブラウザタブのタイトル
- `app/layout.tsx`の`metadata.title`で設定

---

## 📋 日利処理システム（2025年10月9日更新）

### RPC関数統合
**背景:**
- 2025年10月1日～9日: 管理画面から直接DB書き込みで日利設定（旧方式）
- 問題: NFT自動付与と紹介報酬計算が実行されない

**解決:**
- `process_daily_yield_with_cycles` RPC関数を使用するように変更
- 管理画面の日利設定が以下を自動実行:
  1. 日次利益配布
  2. 紹介報酬計算・配布（各レベル20%/10%/5%）
  3. NFT自動付与（cum_usdt >= $2,200到達時）

### 実装内容
**フロントエンド (`app/admin/yield/page.tsx`):**
```typescript
// 旧方式（直接DB書き込み）
await supabase.from('user_daily_profit').insert(...)

// 新方式（RPC関数経由）
await supabase.rpc('process_daily_yield_with_cycles', {
  p_date: date,
  p_yield_rate: yieldValue,
  p_margin_rate: marginValue,
  p_is_test_mode: false,
  p_skip_validation: false
})
```

**成功メッセージ:**
```
✅ 日利設定完了

処理詳細:
• 日利配布: XX名に総額$XXX.XX
• 紹介報酬: XX名に配布
• NFT自動付与: XX名に付与
• サイクル更新: XX件
```

### データリセット手順
旧方式で設定した日利データをリセットする場合:
```sql
-- scripts/reset-old-yield-data-1001-1009.sql
-- 10/1～10/9の日利・紹介報酬・自動NFTを削除
-- affiliate_cycleをリセット（手動NFTのみ残す）
```

### 重要な注意事項
- **テストモード削除**: 管理画面からテストモードUI完全削除（本番運用のみ）
- **未来日付チェック**: 今日より未来の日付には設定不可
- **重複処理防止**: 同一日付の再設定時は既存データを上書き

---

## 👤 運用専用ユーザー機能（2025年10月9日実装）

### 概要
紹介機能を使わず、自分の運用のみを行うユーザー向けの機能

### 仕様
**データベース:**
- `users.is_operation_only` (BOOLEAN, DEFAULT false)

**表示される項目:**
- ✅ 累積USDT
- ✅ 確定USDT
- ✅ 出金状況
- ✅ グラフ
- ✅ 自動NFT購入履歴
- ✅ NFT買い取り申請

**非表示項目（ダッシュボード）:**
- ❌ 紹介報酬カード
- ❌ 紹介ネットワーク（組織図）
- ❌ Level3紹介報酬
- ❌ レベル別投資額統計
- ❌ Level4以降の総計

**非表示項目（プロフィール）:**
- ❌ 紹介リンク
- ❌ QRコード

### 重要な注意事項
1. **紹介報酬の計算は通常通り実行される**
   - 運用専用ユーザー自身に紹介者がいる場合、その紹介者には報酬が入る
   - NFT自動付与も通常通り機能する
   - UIのみ非表示（バックエンド計算は影響なし）

2. **設定方法**
   - `/admin/users` のユーザー編集画面
   - 「運用専用ユーザー」チェックボックスにチェック

3. **実装ファイル**
   - `app/dashboard/page.tsx`: 紹介UIの条件分岐
   - `app/profile/page.tsx`: 紹介リンクの条件分岐
   - `app/admin/users/page.tsx`: 編集フォームのチェックボックス

### SQL設定
```sql
-- scripts/add-is-operation-only-field.sql
ALTER TABLE users ADD COLUMN is_operation_only BOOLEAN DEFAULT FALSE;
```

---

## 🔧 管理画面の改善（2025年10月9日）

### NFT配布ボタンの確認ダイアログ
**場所:** `/admin/users`

**動作:**
```javascript
// 配布済みに設定する場合
confirm('NFT配布状況を「配布済みに設定」しますか？')

// リセットする場合
confirm('NFT配布状況を「配布状況をリセット」しますか？')
```

**目的:** 誤操作防止

### 購入詳細モーダルに報酬受取アドレス追加
**場所:** `/admin/purchases` - 詳細ボタン

**追加項目:**
- ラベル: 「報酬受取アドレス」
- データ: `users.nft_receive_address`
- 表示: フルネームの下に配置
- フォーマット: モノスペースフォント、折り返しあり

**SQL更新:**
```sql
-- scripts/add-nft-receive-address-to-admin-view.sql
-- admin_purchases_viewにnft_receive_addressカラムを追加
```

---

## 🛠 開発環境

- Next.js 14 + TypeScript
- Supabase（データベース + RPC関数）
- Tailwind CSS（スタイリング）
- 段階的読み込み最適化（4ステージ）

---

## 📞 サポート

問題が発生した場合は、以下の情報と共に報告してください：
1. エラーメッセージ
2. 発生した操作
3. ユーザーID
4. ブラウザ情報

---

最終更新: 2025年10月9日