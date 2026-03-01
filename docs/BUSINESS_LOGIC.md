# HASHPILOT ビジネスロジック詳細

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

**正しいルール:**
- **① 毎月5日までに購入** → 当月15日より運用開始
- **② 毎月6日～20日に購入** → 翌月1日より運用開始
- **③ 毎月21日～月末に購入** → 翌月15日より運用開始

**例:**
- 10/3購入 → 10/15運用開始
- 10/15購入 → 11/1運用開始
- 10/28購入 → 11/15運用開始

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
- **マイナス利益時**: マージン30%を引く（会社が負担する）

### 計算式
#### 共通計算式（プラス・マイナス共通）
```
ユーザー受取率 = 日利率 × (1 - 0.30) × 0.6
例1（プラス）: +1.6% → 1.6% × 0.7 × 0.6 = 0.672%
例2（マイナス）: -0.2% → -0.2% × 0.7 × 0.6 = -0.084%
```

### なぜこの計算方式？
プラス・マイナスで一貫した計算にすることで、月間累計でも正しく機能する：
```
例：+$500, +$500, +$500, -$500 の場合（元本$50,000）
- 日次ユーザー受取: +$210, +$210, +$210, -$210 = +$420
- 日次会社マージン: +$290, +$290, +$290, -$290 = +$580
- 月間累計利益: $1,000
- ユーザー受取率: 42%（= 70% × 60%）✅
- 会社マージン率: 58%（= 30% + 40%未配当）✅
```

### 重要な変更履歴
- 2025/11/01: マイナス時の計算を修正（× 1.3 → × 0.7）プラスと統一
- 2025/08/24: マイナス時のマージン計算を修正（0% → 30%補填）← 誤り
- 月末調整処理は不要（日次処理で自動的に正しくなる）

---

## 🔄 NFTサイクルシステム（2025年12月3日更新）

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

### ⚠️ 紹介報酬のデータソース（重要）

**日次紹介報酬は廃止。全て月次紹介報酬を使用する。**

| テーブル | 用途 | 備考 |
|----------|------|------|
| `monthly_referral_profit` | ✅ 正しいデータソース | 月次紹介報酬（現在使用中） |
| `user_referral_profit` | ❌ 使用しない | 旧・日次紹介報酬（廃止） |

### cum_usdtの同期ルール

`affiliate_cycle.cum_usdt`は`monthly_referral_profit`の合計と一致させる必要がある。

**同期が必要な場合のSQL:**
```sql
-- cum_usdtをmonthly_referral_profitの合計で更新
UPDATE affiliate_cycle ac
SET cum_usdt = COALESCE(mrp.total_referral, 0)
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id;

-- phaseを再計算
UPDATE affiliate_cycle
SET phase = CASE
  WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
  ELSE 'HOLD'
END
WHERE cum_usdt >= 0;
```

**確認用SQL:**
```sql
-- 不整合チェック
SELECT
  ac.user_id,
  ac.cum_usdt,
  COALESCE(mrp.total, 0) as monthly_referral_total,
  ac.cum_usdt - COALESCE(mrp.total, 0) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(ac.cum_usdt - COALESCE(mrp.total, 0)) > 0.01
ORDER BY ABS(ac.cum_usdt - COALESCE(mrp.total, 0)) DESC;
```

### 2025年12月3日の修正
- `cum_usdt`が`monthly_referral_profit`と不一致だったため同期実施
- 全ユーザーの`cum_usdt`を`monthly_referral_profit`の合計で上書き
- `phase`を再計算

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

### 購入詳細モーダルにNFT受取アドレス追加
**場所:** `/admin/purchases` - 詳細ボタン

**追加項目:**
- ラベル: 「NFT受取アドレス」
- データ: `users.nft_receive_address`
- 表示: フルネームの下に配置
- フォーマット: モノスペースフォント、折り返しあり

**SQL更新:**
```sql
-- scripts/add-nft-receive-address-to-admin-view.sql
-- admin_purchases_viewにnft_receive_addressカラムを追加
```

---

## 🔄 解約（全NFT売却）時の自動フラグ更新（2025年12月23日実装）

### 概要
ユーザーが全NFTを売却（buyback）した際に、自動的に解約済みフラグを設定するトリガー。

### 自動更新される項目

**`users`テーブル:**
- `is_active_investor = false`
- `has_approved_nft = false`
- `total_purchases = 0`

**`affiliate_cycle`テーブル:**
- `manual_nft_count = 0`
- `total_nft_count = 0`

### トリガーの動作条件
- `nft_master.buyback_date`が`NULL`から日付に更新された時
- かつ、そのユーザーの残りNFT数が0になった時

### 実装

**トリガー関数:** `update_user_active_status()`

**トリガー:** `trigger_update_active_status`
- テーブル: `nft_master`
- イベント: `AFTER UPDATE OF buyback_date`
- 条件: `NEW.buyback_date IS NOT NULL AND OLD.buyback_date IS NULL`

### セットアップSQL
```bash
scripts/FIX-dormant-trigger-complete.sql
```

### 関連機能
- 解約ユーザーのUI対応（ダッシュボードにバナー表示、NFT購入不可など）
- 解約ユーザーの紹介報酬は会社アカウント（7A9637）に入る設定

---

## 🎯 NFTごとの運用開始日管理（2026年1月2日実装）

### 重大バグの修正

**問題:**
- 既存ユーザーが追加でNFTを購入した場合、承認即日から運用開始されていた
- 例: 9A3A16（11/1運用開始済み）が12/7に8NFT追加購入 → 12/7から8NFT分の日利が配布
- 本来は追加購入NFTも通常のルールに従い、運用開始日まで待機すべき

**原因:**
- `process_daily_yield_v2`が`users.operation_start_date`のみチェックしていた
- ユーザーの運用開始日が過去なら、新規購入NFTも即座にカウントされていた

### 修正内容

**1. `nft_master`テーブルに`operation_start_date`カラムを追加**
```sql
ALTER TABLE nft_master ADD COLUMN operation_start_date DATE;
COMMENT ON COLUMN nft_master.operation_start_date IS 'このNFTの運用開始日（acquired_dateから計算）';
```

**2. 既存NFTの`operation_start_date`を設定**
```sql
UPDATE nft_master nm
SET operation_start_date = calculate_operation_start_date(nm.acquired_date)
WHERE nm.operation_start_date IS NULL;
```

**3. トリガーで自動設定**
```sql
CREATE TRIGGER trigger_set_nft_operation_start_date
  BEFORE INSERT OR UPDATE OF acquired_date ON nft_master
  FOR EACH ROW
  EXECUTE FUNCTION set_nft_operation_start_date();
```

**4. `process_daily_yield_v2`の修正**
```sql
-- 修正前：ユーザーの運用開始日のみチェック
WHERE u.operation_start_date <= p_date

-- 修正後：NFTごとの運用開始日をチェック
WHERE nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= p_date
```

### 運用開始日の計算ルール（NFTごとに適用）

| 購入日 | 運用開始日 |
|--------|------------|
| 毎月5日まで | 当月15日 |
| 毎月6日〜20日 | 翌月1日 |
| 毎月21日〜月末 | 翌月15日 |

**例:**
- 12/7に追加購入 → 1/1運用開始
- 12/25に追加購入 → 1/15運用開始

### 関連スクリプト

- `scripts/FIX-process-daily-yield-v2-nft-operation-start.sql` - 完全修正スクリプト

### 影響範囲

- 1月以降の日利計算が正しくなる
- 12月分は既に配布済みのため修正しない（影響額は小さい）
- ユーザー・管理者画面にNFTごとの運用開始日を表示予定

---

## 💸 月末出金システムの改善（2025年12月18日）

### 概要
11月分の月末出金データに個人利益・紹介報酬の内訳を追加し、出金済み紹介報酬を正しく追跡するように修正。

### データベース変更

**`monthly_withdrawals`テーブル:**
- `personal_amount`: 個人利益（日利合計）
- `referral_amount`: 紹介報酬
- `total_amount`: 出金合計（personal_amount + referral_amount）

**`affiliate_cycle`テーブル:**
- `withdrawn_referral_usdt`: 出金済み紹介報酬の累積額（新規追加）

### 11月データの修正内容

1. **personal_amountの設定**
   - `nft_daily_profit`テーブルから11月の日利合計を取得
   - `scripts/FIX-november-withdrawal-personal-amount.sql`

2. **referral_amountの設定**
   - `monthly_referral_profit`テーブルから11月の紹介報酬合計を取得
   - `scripts/FIX-november-withdrawal-referral-amounts.sql`

3. **withdrawn_referral_usdtの設定**
   - 11月に紹介報酬を出金した150名のユーザーに対して設定
   - 合計$7,608.97の出金済み紹介報酬を記録
   - `scripts/FIX-all-november-withdrawn-referral.sql`

4. **金額の丸め処理**
   - 全ての金額を小数点第二位で丸め
   - 微小なマイナス値（-0.004など）は0に修正

### 管理画面の変更（`/admin/withdrawals`）

**表示項目:**
- フェーズ（USDT/HOLD）
- 個人利益
- 紹介報酬
- 出金合計

**CSVエクスポート:**
- フェーズ、個人利益、紹介報酬、出金合計を含む

### ユーザー画面の変更（`/withdrawal`）

**`components/pending-withdrawal-card.tsx`:**
- 保留中・完了済み両方の出金履歴で内訳を表示
- 個人利益: 緑色で表示
- 紹介報酬: 青色で表示

### 関連スクリプト

| スクリプト | 用途 |
|------------|------|
| `scripts/FIX-november-withdrawal-personal-amount.sql` | 11月のpersonal_amount設定 |
| `scripts/FIX-november-withdrawal-referral-amounts.sql` | 11月のreferral_amount設定 |
| `scripts/FIX-all-november-withdrawn-referral.sql` | withdrawn_referral_usdt一括設定 |
| `scripts/CHECK-all-november-referral-withdrawals.sql` | 修正が必要なユーザーの確認 |
| `scripts/CHECK-59C23C-withdrawal-data.sql` | 個別ユーザーの確認 |

### 二重払い防止の仕組み

今後の月末出金処理では、以下の計算で出金可能な紹介報酬を算出：

```sql
出金可能な紹介報酬 = cum_usdt - withdrawn_referral_usdt
```

**注意:**
- HOLDフェーズのユーザーは紹介報酬を出金不可（次のNFT購入に使用予定）
- USDTフェーズのユーザーのみ紹介報酬を出金可能

---

## 📊 出金管理画面の表示仕様（2026年2月7日更新）

### 紹介報酬列の表示

| 表示項目 | 色 | データソース |
|----------|-----|--------------|
| 当月紹介報酬 | 青 | `monthly_referral_profit`（その月のyear_month） |
| 累計 | 紫 | `monthly_referral_profit`（その月以前の合計） |
| 出金額 | 緑 | `monthly_withdrawals.referral_amount` |
| HOLD | オレンジ | `affiliate_cycle.phase = 'HOLD'`の場合 |
| NFT回数 | ピンク | `auto_nft_count > 0`の場合 |

### 累計紹介報酬の計算

#### 🚨 Supabaseの1000件制限に注意

Supabaseはデフォルトで1000件までしかデータを返さない。`.limit()`や`.range()`では回避できない（プロジェクト設定で制限されている）。

**問題:**
```typescript
// ❌ これだと1000件で切り捨てられる
const { data } = await supabase
  .from("monthly_referral_profit")
  .lte("year_month", yearMonth)
  .in("user_id", userIds)
// 12月・1月のデータが取得できない
```

**解決策: 月ごとに分割取得**
```typescript
// ✅ 月ごとに分けて取得して結合
const targetMonths = ['2025-11', '2025-12', '2026-01'] // 動的に生成

let allData: any[] = []
for (const ym of targetMonths) {
  const { data: monthData } = await supabase
    .from("monthly_referral_profit")
    .select("user_id, profit_amount, year_month")
    .eq("year_month", ym)  // 月ごとにフィルター
    .in("user_id", userIds)
    .range(0, 4999)

  if (monthData) {
    allData = allData.concat(monthData)
  }
}

// ユーザーごとに累計を計算
const cumulativeMap = new Map<string, number>()
allData.forEach(r => {
  const current = cumulativeMap.get(r.user_id) || 0
  cumulativeMap.set(r.user_id, current + Number(r.profit_amount))
})
```

**なぜこれで解決するか:**
- 1ヶ月分のデータは1000件未満
- 月ごとに取得すれば全データを取得可能
- 結合後に累計を計算

**注意:** `affiliate_cycle.cum_usdt`は現在値のため、月を切り替えても同じ値になる。
月別の累計を表示するには`monthly_referral_profit`から月ごとに分割取得して計算する必要がある。

### 出金合計列の表示

- メイン: `total_amount`
- 内訳: `個人: $XX.XX + 紹介: $XX.XX`

---

## 🔐 CoinW UID変更承認機能（2025年12月20日実装）

### 概要
ユーザーがプロフィールページでCoinW UIDを変更する際、管理者の承認が必要になる機能。
承認されると自動的に`channel_linked_confirmed = true`に設定される。

### データベース

**`coinw_uid_changes`テーブル:**
```sql
CREATE TABLE coinw_uid_changes (
  id UUID PRIMARY KEY,
  user_id VARCHAR(6) NOT NULL,
  old_coinw_uid VARCHAR(255),
  new_coinw_uid VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',  -- pending/approved/rejected
  created_at TIMESTAMPTZ,
  reviewed_at TIMESTAMPTZ,
  reviewed_by VARCHAR(255),
  rejection_reason TEXT
);
```

**`users`テーブルに追加:**
- `channel_linked_confirmed` BOOLEAN - チャンネル紐付け確認済みフラグ

### RPC関数
- `approve_coinw_uid_change(p_change_id, p_admin_email)` - 承認処理
- `reject_coinw_uid_change(p_change_id, p_admin_email, p_reason)` - 却下処理

### Edge Function
- `send-coinw-rejection-email` - 却下時にメール送信

### 画面
- `/admin/coinw-approvals` - 管理者用承認画面
- `/profile` - ユーザーの申請・却下理由表示

### セットアップSQL
```bash
scripts/ADD-channel-linked-confirmed-column.sql
scripts/CREATE-coinw-uid-changes-table.sql
```

### Edge Functionデプロイ
```bash
npx supabase functions deploy send-coinw-rejection-email
```

---

## 🔧 運用開始日の安全な変更機能（2025年12月6日実装）

### 背景
運用開始日を変更すると、その日付より前に配布された日利・紹介報酬データと不整合が発生する問題があった。

**例: D2C1F9のケース**
- 運用開始日を12/15に変更
- しかし12/1〜12/5の日利が既に配布済み
- 不整合データが残ったままになる

### 解決策
運用開始日を変更した際に、自動的に不整合データを削除するRPC関数を実装。

### RPC関数: `update_operation_start_date_safe`

**ファイル:** `scripts/CREATE-update-operation-start-date-safe.sql`

**機能:**
1. 新しい運用開始日より前の`nft_daily_profit`を削除
2. 新しい運用開始日より前の`user_referral_profit`を削除
3. `affiliate_cycle`の`available_usdt`と`cum_usdt`を自動調整
4. 削除した件数と金額をログとして返却

**パラメータ:**
```sql
p_user_id VARCHAR,           -- ユーザーID（6桁）
p_new_operation_start_date DATE,  -- 新しい運用開始日
p_admin_email VARCHAR        -- 管理者メールアドレス
```

**戻り値:**
```json
{
  "status": "SUCCESS",
  "message": "運用開始日を 2025-12-15 に変更しました",
  "details": {
    "user_id": "D2C1F9",
    "old_operation_start_date": null,
    "new_operation_start_date": "2025-12-15",
    "deleted_profit": { "count": 5, "sum": -0.774 },
    "deleted_referral": { "count": 0, "sum": 0 }
  }
}
```

### 管理画面での使用

**1. ユーザー管理画面 (`/admin/users`)**
- 編集モーダルに「運用開始日」フィールドを追加
- 日付を変更して保存すると自動的に不整合データを削除
- 削除されたデータがある場合はアラートで通知

**2. 購入管理画面 (`/admin/purchases`)**
- 「承認日編集」ボタンで承認日を変更
- 運用開始日が再計算され、自動的に不整合データを削除

### 影響範囲

**この関数が呼ばれるタイミング:**
- 管理者が明示的に運用開始日または承認日を変更した場合のみ

**影響なし:**
- 日利処理 (`process_daily_yield_v2`)
- 月次処理
- ダッシュボード表示
- NFT購入承認 (`approve_user_nft`)

### 関連ファイル
- `scripts/CREATE-update-operation-start-date-safe.sql` - RPC関数定義
- `app/admin/users/page.tsx` - ユーザー管理画面（運用開始日編集）
- `app/admin/purchases/page.tsx` - 購入管理画面（承認日編集）

---

最終更新: 2026年3月1日
