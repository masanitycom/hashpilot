# HASHPILOT システム管理ガイド

## 🚨🚨🚨 日次処理と月末処理の分離（最重要）🚨🚨🚨

**絶対に守ること：日次処理と月末処理は完全に分離する**

### 日次処理（`process_daily_yield_v2`）
| 項目 | 実行 | 備考 |
|------|------|------|
| 個人利益配布（60%） | ✅ 実行 | available_usdtに加算 |
| 紹介報酬計算 | ❌ 実行しない | 月末処理で実行 |
| cum_usdt更新 | ❌ 実行しない | 月末処理で実行 |
| NFT自動付与 | ❌ 実行しない | 月末処理で実行 |

### 月末処理（`process_monthly_referral_reward`）
| 項目 | 実行 | 備考 |
|------|------|------|
| 紹介報酬計算（30%） | ✅ 実行 | monthly_referral_profitに保存 |
| cum_usdt更新 | ✅ 実行 | 紹介報酬のみ |
| phase再計算 | ✅ 実行 | USDT/HOLD判定 |
| NFT自動付与 | ✅ 実行 | cum_usdt >= 2200 |

### ⚠️ 禁止事項
- `process_daily_yield_v2`に紹介報酬計算を追加してはいけない
- `process_daily_yield_v2`にNFT自動付与を追加してはいけない
- `user_referral_profit`テーブル（日次紹介報酬）は廃止済み、使用禁止

### 関連テーブル
| テーブル | 用途 | 更新タイミング |
|----------|------|----------------|
| `nft_daily_profit` | 日次個人利益 | 日次処理 |
| `monthly_referral_profit` | 月次紹介報酬 | 月末処理 |
| `affiliate_cycle.available_usdt` | 出金可能額 | 日次+月末 |
| `affiliate_cycle.cum_usdt` | 紹介報酬累計 | 月末処理のみ |

---

## 🚨 紹介報酬計算の絶対ルール（最重要）

**紹介報酬は月末の合計利益で計算する。日々のプラス・マイナスは関係ない。**

### 正しい計算方法：
```sql
-- ✅ 正しい：プラス・マイナス両方を含める
CREATE TEMP TABLE temp_monthly_profit AS
SELECT
  user_id,
  SUM(daily_profit) as monthly_profit  -- 月末合計（プラス・マイナス含む）
FROM user_daily_profit
WHERE date >= v_start_date AND date <= v_end_date
GROUP BY user_id;

-- ❌ 間違い：プラス日利のみで計算
WHERE daily_profit > 0  -- これは絶対に使わない
```

### 例：9A3A16（156 NFT）の11月
- 全日利合計: **$4,994.184**（これを使う）
- プラス日利のみ: $8,525.712（使わない）
- マイナス日利: -$3,531.528（月末合計に含まれる）

### 紹介報酬の計算：
- Level 1: $4,994.184 × 20% = $998.84
- Level 2: $4,994.184 × 10% = **$499.42**
- Level 3: $4,994.184 × 5% = $249.71

### 重要な注意：
- 個人利益：プラス・マイナス両方を反映
- 紹介報酬：**月末合計がプラスの場合のみ**配布（`monthly_profit > 0`）
- マイナス月末合計の場合：紹介報酬は$0

---

## 📁 ファイル保存ルール

**重要:** SQLスクリプトやドキュメントを作成する際は、必ず以下のディレクトリに保存すること：

- **SQLスクリプト**: `scripts/` ディレクトリ（例: `scripts/CHECK-xxx.sql`）
- **ドキュメント**: プロジェクトルート（例: `CLAUDE.md`, `FIX-XXX.md`）
- **一時ファイル禁止**: `/tmp/` に保存しない

**命名規則:**
- 確認系: `CHECK-xxx.sql`
- 修正系: `FIX-xxx.sql`
- 削除系: `DELETE-xxx.sql`
- 調査系: `INVESTIGATE-xxx.sql`
- 緊急系: `URGENT-xxx.sql`

---

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

## 📧 システムメール機能（2025年10月11日実装）

### 概要
管理者からユーザーへのメール送信機能（一斉送信・個別送信）

### 機能
1. **一斉メール送信**
   - 全ユーザー
   - 承認済みユーザーのみ
   - 未承認ユーザーのみ

2. **個別メール送信**
   - 特定のユーザーIDを指定して送信

3. **メール送信履歴**
   - 管理者の送信履歴表示
   - 配信状況確認（送信成功/失敗/既読）

4. **ユーザー受信箱**
   - 受信メール一覧表示
   - 未読/既読管理
   - メール本文表示（HTML対応）

### データベーステーブル
- `system_emails`: メール本体
- `email_recipients`: 送信先・配信状況
- `email_templates`: メールテンプレート（将来拡張用）

### RPC関数
- `create_system_email()`: メール作成＆送信先登録
- `get_user_emails()`: ユーザーのメール一覧取得
- `mark_email_as_read()`: メールを既読にする
- `get_email_history()`: 管理者用メール送信履歴
- `get_email_delivery_details()`: メール配信詳細

### Edge Function
- `send-system-email`: Resend APIでメール送信処理

### 画面
- `/admin/emails`: 管理者メール送信画面（一斉・個別・履歴）
- `/inbox`: ユーザー受信箱

### メール送信フロー
1. 管理者が件名・本文・送信先を指定
2. `create_system_email()` でメール作成＆送信先登録
3. `send-system-email` Edge Functionでメール送信
4. 送信結果を `email_recipients` に記録

### セットアップ手順
1. SQLスクリプト実行:
   ```bash
   scripts/create-email-system-tables.sql
   scripts/create-email-rpc-functions.sql
   ```

2. Edge Functionデプロイ:
   ```bash
   npx supabase functions deploy send-system-email
   ```

3. Supabase環境変数設定:
   - `RESEND_API_KEY`: Resend APIキー

### 重要な注意事項
- メール送信にはResend APIを使用（`noreply@send.hashpilot.biz`）
- HTML形式のメール本文に対応
- 送信失敗時は `email_recipients.error_message` に記録
- RLS（Row Level Security）で権限制御済み

---

## 🔧 Staging環境（テスト環境）

### 概要
本番環境に影響を与えずにテストできる環境を提供します。

### 環境構成
- **本番環境**: https://hashpilot.net (mainブランチ)
- **テスト環境**: https://hashpilot-staging.vercel.app (stagingブランチ)

### ブランチ戦略
```
main ブランチ        → 本番環境
staging ブランチ     → テスト環境（ベーシック認証あり）
```

### 開発フロー

**1. テスト環境で開発・テスト**
```bash
git checkout staging
# コード修正...
git add .
git commit -m "新機能追加"
git push origin staging  # テスト環境に自動デプロイ
```

**2. テストOK → 本番環境に反映**
```bash
git checkout main
git merge staging
git push origin main     # 本番環境に自動デプロイ
```

### ベーシック認証
- **テスト環境のみ有効**
- ユーザー名: `admin` (環境変数 `BASIC_AUTH_USER`)
- パスワード: 環境変数 `BASIC_AUTH_PASSWORD` で設定

### Vercel環境変数設定

**Production（本番）:**
```env
NEXT_PUBLIC_ENV=production
NEXT_PUBLIC_SITE_URL=https://hashpilot.net
```

**Preview（テスト）:**
```env
NEXT_PUBLIC_ENV=staging
BASIC_AUTH_USER=admin
BASIC_AUTH_PASSWORD=(強力なパスワード)
NEXT_PUBLIC_SITE_URL=https://hashpilot-staging.vercel.app
```

### 詳細ドキュメント
完全なセットアップ手順は `STAGING_SETUP.md` を参照してください。

---

## 🐛 重要なバグ修正履歴

### 運用開始日未設定ユーザーへの誤配布（2025年11月13日修正）

**問題:**
- `process_daily_yield_with_cycles`関数で、`operation_start_date IS NULL`（運用開始日未設定）のユーザーも日利と紹介報酬の対象になっていた
- 38名のユーザーが合計$340.902の日利を誤って受け取っていた（2025-11-05 ～ 2025-11-11）

**原因:**
```sql
-- 修正前の条件（STEP 2とSTEP 3）
WHERE u.has_approved_nft = true
AND (u.operation_start_date IS NULL OR u.operation_start_date <= p_date)
```

**修正内容:**
```sql
-- 修正後の条件（STEP 2とSTEP 3）
WHERE u.has_approved_nft = true
AND u.operation_start_date IS NOT NULL
AND u.operation_start_date <= p_date
```

**修正箇所:**
- STEP 2: 個人利益計算（ユーザーごとに集計）
- STEP 3: 紹介報酬計算（レベル1/2/3すべて）

**関連スクリプト:**
- `scripts/FIX-operation-start-date-null-users.sql` - 関数修正
- `scripts/CHECK-incorrect-daily-profit-details.sql` - 誤配布データ確認
- `scripts/DELETE-incorrect-daily-profit-CAREFUL.sql` - 誤配布データ削除（要慎重）

**運用ルールの再確認:**
> 運用開始日が設定されていて（IS NOT NULL）、かつその日付が経過している（<= 今日）ユーザーのみが日利と紹介報酬の対象

---

### マイナス日利が配布されない問題（2025年11月13日修正）

**問題:**
- `process_daily_yield_v2`関数がマイナス日利の時に配当を0にしていた
- ユーザーダッシュボードにマイナス日利が表示されない
- 透明性の問題（マイナスが隠されていた）

**原因:**
```sql
-- 修正前のStep 9（行142-150）
IF v_daily_pnl > 0 THEN
  v_distribution_dividend := v_daily_pnl * 0.60;
  v_distribution_affiliate := v_daily_pnl * 0.30;
  v_distribution_stock := v_daily_pnl * 0.10;
ELSE
  v_distribution_dividend := 0;  -- ❌ マイナス時は0
  v_distribution_affiliate := 0;
  v_distribution_stock := 0;
END IF;

-- 修正前のStep 11-13
IF v_distribution_dividend > 0 THEN  -- ❌ プラスのみ処理
```

**修正内容:**
```sql
-- 修正後のStep 9（マイナスでも計算）
v_distribution_dividend := v_daily_pnl * 0.60;   -- ✅ 常に計算
v_distribution_affiliate := v_daily_pnl * 0.30;
v_distribution_stock := v_daily_pnl * 0.10;

-- 修正後のStep 11-13
IF v_distribution_dividend != 0 THEN  -- ✅ マイナスでも処理
```

**追加修正:**
- `nm.status = 'active'` → `nm.buyback_date IS NULL`（テスト環境のテーブル構造に対応）

**関連スクリプト:**
- `scripts/FIX-process-daily-yield-v2-final.sql` - 関数修正（最終版）
- `scripts/FIX-process-daily-yield-v2-minimal.sql` - 最小限版
- `scripts/FIX-process-daily-yield-v2-negative.sql` - 詳細コメント版

**テスト結果:**
- ユーザー7A9637の11/12に-$0.912が正しく配布・表示された
- ダッシュボードで「昨日の利益: $-0.912」と表示
- 今月累計は$12.493で正しく計算

**CLAUDE.md仕様の確認:**
> **マイナス利益時**: マージン30%を引く（会社が負担する）
>
> ユーザー受取率 = 日利率 × (1 - 0.30) × 0.6
> 例：-0.2% → -0.2% × 0.7 × 0.6 = -0.084%

---

### NFT承認フラグ未更新問題（2025年11月13日修正）

**問題:**
- 管理者がNFT購入を承認したが、`users.has_approved_nft`が`false`のまま
- `users.operation_start_date`が`null`のまま
- **81名のユーザーが日利を受け取れていなかった**

**原因:**
- NFT承認時に`nft_master`テーブルにはNFTが作成される
- しかし`users`テーブルの以下のフラグが更新されていなかった：
  - `has_approved_nft` → `false`のまま
  - `operation_start_date` → `null`のまま
- このため、NFTは存在するが日利が配布されない状態だった

**影響:**
- 81名のユーザー（合計89個のNFT）が日利を受け取れていなかった
- `nft_master`にはNFTが存在するため、NFT数はカウントされる
- でも`operation_start_date`が未設定のため、日利は0円

**修正内容:**
```sql
-- has_approved_nftを一括更新（361件）
UPDATE users
SET has_approved_nft = true
WHERE user_id IN (
    SELECT DISTINCT u.user_id
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    INNER JOIN purchases p ON u.user_id = p.user_id
    WHERE u.has_approved_nft = false
        AND p.admin_approved = true
        AND nm.buyback_date IS NULL
);

-- operation_start_dateを一括計算・更新（363件）
UPDATE users u
SET operation_start_date = calculate_operation_start_date(nm.acquired_date)
FROM (
    SELECT DISTINCT ON (user_id)
        user_id,
        acquired_date
    FROM nft_master
    WHERE buyback_date IS NULL
    ORDER BY user_id, acquired_date ASC
) nm
WHERE u.user_id = nm.user_id
    AND u.operation_start_date IS NULL;
```

**関連スクリプト:**
- `scripts/FIX-has-approved-nft-bulk-update.sql` - 一括修正スクリプト

**確認方法:**
```sql
-- 同じ問題がないか確認
SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.has_approved_nft = false
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.email, u.has_approved_nft, u.operation_start_date;
```

**今後の対策:**
- NFT承認時に`has_approved_nft`と`operation_start_date`を自動更新する仕組みが必要
- または管理画面のNFT承認処理を修正

---

### approve_user_nft関数で運用開始日が未設定になる問題（2025年12月17日修正）

**問題:**
- 12/15運用開始のユーザーが運用益0のまま
- 日利設定は12/16まで設定済みなのに配布されていない

**原因:**
- `approve_user_nft`関数がNFT承認時に以下を設定していなかった：
  - `has_approved_nft = true`
  - `operation_start_date = calculate_operation_start_date(承認日)`
- これにより`process_daily_yield_v2`の対象外になっていた

**修正内容:**
- `approve_user_nft`関数を修正
- `users`テーブル更新時に`has_approved_nft`と`operation_start_date`を設定

**補填処理:**
- 12/15と12/16の日利を手動でバックフィル
- `nft_daily_profit`テーブルに直接挿入（user_daily_profitはビューのため）
- `affiliate_cycle.available_usdt`も更新

**関連スクリプト:**
- `scripts/FIX-approve-user-nft-add-operation-start-date.sql` - 関数修正
- `scripts/FIX-1215-backfill-simple.sql` - 日利補填

---

### V2日利システム完成（2025年11月13日）

**背景:**
- 旧システム: 利率％で入力 → `process_daily_yield_with_cycles`
- V2システム: 金額＄で入力 → `process_daily_yield_v2`
- **機能は全く同じ。入力方法だけ変更。**

**実装内容:**
1. ✅ **日利配布（個人利益）** - 60%を配当として配布
   - マイナス日利も配布する
   - `affiliate_cycle.available_usdt`に加算

2. ✅ **紹介報酬計算・配布** - 30%を紹介報酬として配布
   - Level 1（直接紹介）: 紹介者の日利 × 20%
   - Level 2（間接紹介）: 紹介者の日利 × 10%
   - Level 3（間接紹介）: 紹介者の日利 × 5%
   - **プラスの時のみ計算**（マイナス時は紹介報酬なし）
   - `user_referral_profit`テーブルに記録
   - `affiliate_cycle.cum_usdt`と`available_usdt`に加算

3. ✅ **NFT自動付与（サイクル機能）** - 10%をストック資金
   - `cum_usdt >= $2,200`で自動的に1 NFT付与
   - `nft_master`にレコード作成（`nft_type = 'auto'`）
   - `purchases`にレコード作成
   - `cum_usdt -= 1100`, `available_usdt += 1100`
   - フェーズ更新（USDT / HOLD）

**テスト結果（2025-11-11、+$1580.32）:**
- 個人利益: 255ユーザーに$948.040配布
- 紹介報酬: 135ユーザーに$296.345配布（649件の紹介関係）
  - Level 1: 132ユーザー、$185.224（20%）
  - Level 2: 90ユーザー、$89.735（10%）
  - Level 3: 73ユーザー、$21.386（5%）
- ストック資金: 255ユーザーに$158.450配布
- NFT自動付与: 0件（cum_usdt >= $2,200のユーザーなし）

**具体例（ユーザー7A9637）:**
- 個人利益: $1.370（1 NFT所有）
- 紹介報酬:
  - Level 1: 2人から$0.548（各$0.274 = $1.370 × 20%）
  - Level 2: 3人から$0.548
  - Level 3: 2人から$0.138
  - 合計: $1.234
- affiliate_cycle更新:
  - `cum_usdt`: $1.23（紹介報酬のみ）
  - `available_usdt`: $2.60（個人利益 + 紹介報酬）

**関連スクリプト:**
- `scripts/FIX-process-daily-yield-v2-complete-clean.sql` - 完成版RPC関数
- `scripts/TEST-process-daily-yield-v2-positive.sql` - テストスクリプト

**管理画面での使用:**
- `app/admin/yield/page.tsx`で既に`process_daily_yield_v2`を使用中
- 入力: 日付、金額（＄）
- 出力: 日利配布、紹介報酬、NFT自動付与の詳細

---

### 本番環境の緊急修正（2025年11月15日）

**🚨 重大な問題が発見され、システム停止が必要となりました。**

#### 問題の詳細

1. **運用開始前のユーザーへの誤配布**
   - `operation_start_date IS NULL` または `operation_start_date > 配布日` のユーザーにも日利と紹介報酬が配布されていた
   - 本番環境のV1システム（`process_daily_yield_with_cycles`）で発生
   - テスト環境で同じ問題が発見・修正済みだったが、本番環境には未適用だった

2. **NFT承認フラグ未更新（本番環境）**
   - **91ユーザー**が `has_approved_nft = false` または `operation_start_date = NULL`
   - これらのユーザーは合計 **$81,000の投資**（81個のNFT）
   - 実際にはNFTを保有しているが、日利を受け取れていない状態

3. **V1システムの根本的な欠陥**
   - `process_daily_yield_with_cycles`関数が `operation_start_date` をチェックしていなかった
   - STEP 2（個人利益配布）でチェック不足
   - STEP 3（紹介報酬配布）でチェック不足
   - STEP 4（NFT自動付与）でチェック不足

#### 影響範囲

**誤配布されたユーザー:**
- operation_start_date = NULL: 38ユーザー、$81,000投資
- operation_start_date > 配布日: その他のユーザー
- 誤配布された金額: 調査中（`URGENT-CHECK-incorrect-profit-distribution.sql`で確認可能）

**総投資額の変化:**
- 以前: $680,000
- 現在: $714,000
- 内訳:
  - 運用中（ペガサス除く）: $714,000（714 NFT、271ユーザー）
  - 運用開始前（ペガサス除く）: $81,000（81 NFT、38ユーザー）← これが誤配布の原因
  - ペガサス: $87,000（87 NFT、65ユーザー）

#### 緊急対応手順

詳細は **`PRODUCTION_EMERGENCY_FIX.md`** を参照

**STEP 0: システム停止**
- 日利処理を一時停止
- 管理画面で新しい日利を設定しない

**STEP 1: 誤配布データの確認**
```bash
scripts/URGENT-CHECK-incorrect-profit-distribution.sql
```
- operation_start_date = NULL のユーザーへの配布
- operation_start_date > 配布日 のユーザーへの配布
- 誤配布の合計金額、日付別の詳細、ユーザーリスト

**STEP 2: V1システム関数の修正**
```bash
scripts/FIX-process-daily-yield-v1-operation-start-date.sql
```
修正内容:
- STEP 2（個人利益配布）: `operation_start_date IS NOT NULL AND operation_start_date <= p_date` を追加
- STEP 3（紹介報酬配布）: 紹介される側と紹介者の両方の `operation_start_date` をチェック
- STEP 4（NFT自動付与）: `operation_start_date` をチェック

**STEP 3: NFT承認フラグの修正**
```bash
scripts/FIX-production-has-approved-nft-bulk-update.sql
```
- 91ユーザーの `has_approved_nft` を `true` に更新
- 91ユーザーの `operation_start_date` を設定
- 各ユーザーの最初のNFT取得日から `calculate_operation_start_date()` で計算

**STEP 4: 誤配布データの削除**
```bash
scripts/DELETE-incorrect-profit-distribution-CAREFUL.sql
```
⚠️ **この操作は取り消せません。必ずバックアップを取ってください。**

処理内容:
1. `affiliate_cycle.available_usdt` から個人利益分を差し引く
2. `affiliate_cycle.cum_usdt` から紹介報酬分を差し引く
3. `affiliate_cycle.phase` を再計算
4. `nft_daily_profit` から誤配布レコードを削除
5. `user_referral_profit` から誤配布レコードを削除

**STEP 5: システム再開**
- すべての修正が完了後、日利処理を再開
- 検証スクリプトで問題がないことを確認

#### 関連スクリプト

**調査用:**
- `scripts/URGENT-CHECK-incorrect-profit-distribution.sql` - 誤配布データの詳細確認
- `scripts/CHECK-production-v1-profit-analysis.sql` - 本番環境の利益分析
- `scripts/CHECK-total-investment-calculation.sql` - 総投資額計算の確認

**修正用:**
- `scripts/FIX-process-daily-yield-v1-operation-start-date.sql` - V1関数修正
- `scripts/FIX-production-has-approved-nft-bulk-update.sql` - フラグ一括修正
- `scripts/DELETE-incorrect-profit-distribution-CAREFUL.sql` - 誤配布データ削除

**ドキュメント:**
- `PRODUCTION_EMERGENCY_FIX.md` - 緊急修正手順の詳細マニュアル

#### 運用ルールの再確認

**日利・紹介報酬の対象となる条件:**
```sql
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= p_date
```

**重要:**
- 運用開始日が設定されていて（IS NOT NULL）
- かつその日付が経過している（<= 今日）
- ユーザーのみが日利と紹介報酬の対象

**テスト環境との違い:**
- テスト環境: 2025年11月13日に修正済み（`FIX-operation-start-date-null-users.sql`）
- 本番環境: 2025年11月15日に同じ問題が発見され、緊急修正が必要

#### 今後の対策

1. **自動フラグ更新**
   - NFT承認時に `has_approved_nft` と `operation_start_date` を自動更新する仕組みを実装
   - 管理画面のNFT承認処理を修正

2. **V2システムへの移行**
   - 本番環境も将来的にV2システムに移行予定
   - V2システムでは `operation_start_date` チェックが組み込み済み
   - テスト環境で十分にテスト後、本番環境に適用

3. **定期監査**
   - 定期的に誤配布がないかチェックするスクリプトを実行
   - `has_approved_nft = false` だがNFTが存在するユーザーを検出
   - `operation_start_date = NULL` だがNFTが存在するユーザーを検出

---

### approve_user_nft関数の運用開始日設定漏れ（2025年12月17日修正）

**問題:**
- `approve_user_nft`関数でNFTを承認した際に、`users.has_approved_nft`と`users.operation_start_date`が設定されなかった
- そのため、承認済みNFTがあるユーザーでも日利配布の対象外になっていた
- 12/15運用開始予定のユーザーが日利を受け取れない状態だった

**原因:**
```sql
-- 修正前：has_approved_nftとoperation_start_dateが設定されていなかった
UPDATE users u
SET
    total_purchases = u.total_purchases + v_purchase.amount_usd,
    updated_at = NOW()
WHERE u.user_id = v_target_user_id;
```

**修正内容:**
```sql
-- 修正後：has_approved_nftとoperation_start_dateを設定
UPDATE users u
SET
    total_purchases = u.total_purchases + v_purchase.amount_usd,
    has_approved_nft = true,
    operation_start_date = CASE
        WHEN u.operation_start_date IS NULL THEN calculate_operation_start_date(NOW())
        WHEN u.operation_start_date > calculate_operation_start_date(NOW()) THEN calculate_operation_start_date(NOW())
        ELSE u.operation_start_date
    END,
    updated_at = NOW()
WHERE u.user_id = v_target_user_id;
```

**関連スクリプト:**
- `scripts/FIX-approve-user-nft-add-operation-start-date.sql` - 関数修正
- `scripts/FIX-missing-operation-start-date-users.sql` - 既存ユーザーの一括修正
- `scripts/CHECK-1215-operation-start-users.sql` - 問題確認用

**修正後の動作:**
- NFT承認時に`has_approved_nft = true`が自動設定される
- NFT承認時に`operation_start_date`が自動計算・設定される
- 既にoperation_start_dateが設定されている場合は、早い方を維持

**日利配布の条件（再確認）:**
```sql
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= p_date
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
```

---

## 📧 システムメール送信の改善（2025年12月3日）

### バッチ送信機能

**問題:**
- 大量のメール（499件など）を一度に送信するとEdge Functionがタイムアウト（504エラー）
- 一部のメールしか送信されない

**解決策:**
- 50件ずつのバッチ処理を実装
- Edge Function側で`batch_size`パラメータをサポート（最大100件）
- フロントエンドで自動的にバッチを繰り返し送信

### 実装詳細

**Edge Function (`supabase/functions/send-system-email/index.ts`):**
```typescript
const { email_id, batch_size = 50 }: SendEmailRequest = await req.json()
const effectiveBatchSize = Math.min(batch_size, 100)

// pendingのみを取得（バッチサイズで制限）
.eq('email_id', email_id)
.eq('status', 'pending')
.limit(effectiveBatchSize)
```

**フロントエンド (`app/admin/emails/page.tsx`):**
```typescript
const resendPendingEmails = async (emailId: string, pendingCount: number) => {
  const BATCH_SIZE = 50
  while (true) {
    const { data: sendResult } = await supabase.functions.invoke("send-system-email", {
      body: { email_id: emailId, batch_size: BATCH_SIZE },
    })
    if (sendResult.sent_count === 0) break
    await new Promise(resolve => setTimeout(resolve, 1000)) // 1秒待機
  }
}
```

### 緊急停止方法

メール送信を緊急停止する場合：

```sql
-- 全ての未送信を停止
UPDATE email_recipients
SET status = 'failed',
    error_message = 'manually cancelled'
WHERE status = 'pending';
```

**注意:** `status`カラムは`pending`, `sent`, `failed`, `read`のみ許可。`cancelled`は使用不可。

### 再送信手順

停止した後に再送信したい場合：

```sql
-- 特定のメールの手動停止分をpendingに戻す
UPDATE email_recipients
SET status = 'pending',
    error_message = NULL
WHERE email_id = 'メールのUUID'
  AND status = 'failed'
  AND error_message = 'manually cancelled';
```

### 管理画面の再送信ボタン

- 各メールの履歴に「未送信 X件 再送信」ボタンを表示
- 選択したメールのみが黄色でハイライト表示（他は影響なし）
- 送信中はアイコンが回転し「送信中...」と表示
- 全てのボタンは送信中はdisabled（誤操作防止）

### RPC関数の修正

`get_email_history`関数で`pending_count`を追加：

```sql
-- scripts/FIX-get-email-history-correct-column.sql
CREATE OR REPLACE FUNCTION get_email_history(
  p_admin_email TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
  email_id UUID,
  subject TEXT,
  email_type TEXT,
  target_group TEXT,
  created_at TIMESTAMPTZ,
  total_recipients BIGINT,
  sent_count BIGINT,
  failed_count BIGINT,
  read_count BIGINT,
  pending_count BIGINT  -- 追加
)
...
WHERE se.sent_by = p_admin_email  -- created_byではなくsent_by
   OR p_admin_email IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
```

**注意:** `system_emails`テーブルには`created_by`カラムは存在せず、`sent_by`を使用する。

---

## 🔔 CoinW UIDポップアップ（2025年12月3日）

### 機能
- ダッシュボード表示時にCoinW UIDの確認を促すポップアップを表示
- 「次回から表示しない」チェックボックスで非表示設定可能
- `localStorage`に確認状態を保存（`coinw_uid_confirmed_{userId}`）

### 実装ファイル
- `components/coinw-uid-popup.tsx`
- `app/dashboard/page.tsx`（ポップアップの呼び出し）

### 注意事項
- ポップアップは`userData`スコープ内で呼び出す必要がある
- `CoinWAlert`コンポーネント内ではなく、メインの`OptimizedDashboardPage`内に配置

---

## 📊 運用実績サイト（yield.hashpilot.info）（2025年12月4日更新）

### 概要
外部公開用の運用実績表示サイト。Xserverでホスティング。

### ファイル構成
```
xserver/
├── xserver-yield.html       # 運用実績ページ（メイン）
├── xserver-faq.html         # FAQ
├── xserver-faq-redesign.html
├── xserver-guide.html       # ガイド
├── xserver-manual.html      # マニュアル
└── xserver-manual-redesign.html
```

### データ取得の仕組み
1. **Edge Function**: `get-daily-yields`
   - V1テーブル（`daily_yield_log`）: 11月のデータ（利率%）
   - V2テーブル（`daily_yield_log_v2`）: 12月以降のデータ（金額$）
   - 両方を統合して`profit_percentage`（ユーザー受取率%）を返す

2. **HTMLフロントエンド**: `xserver-yield.html`
   - 月選択プルダウン（全期間 / 月別）
   - 統計カード（レコード数、プラス/マイナス日数、期間合計、累積）
   - 日別テーブル（日付、ユーザー受取率%）

### データ形式の違い

**V1（11月、`daily_yield_log`）:**
- `user_rate`は既に%表示（例：0.099 = 0.099%）
- そのまま`profit_percentage`として使用

**V2（12月、`daily_yield_log_v2`）:**
- `profit_per_nft`（1NFTあたりの利益$）から計算
- `userRatePercent = (profit_per_nft / 1000) * 100`
- 例: profit_per_nft = $18.24 → 1.824%

### APIレスポンス例
```json
{
  "date": "2025-12-03",
  "profit_percentage": "1.824",
  "source": "v2"
},
{
  "date": "2025-11-30",
  "profit_percentage": "0.099",
  "source": "v1"
}
```

### デプロイ手順

**Edge Functionの更新（Supabase Dashboard）:**
1. https://supabase.com/dashboard にログイン
2. プロジェクト選択 → Edge Functions → `get-daily-yields`
3. コードを編集（`supabase/functions/get-daily-yields/index.ts`の内容をコピペ）
4. **Deploy**ボタンをクリック

**Edge Functionの更新（CLI）:**
```bash
npx supabase login
npx supabase link --project-ref soghqozaxfswtxxbgeer
npx supabase functions deploy get-daily-yields
```

**注意:** GitHubへのプッシュだけではEdge Functionはデプロイされない。手動でデプロイが必要。

**HTMLの更新:**
1. `xserver/xserver-yield.html`を編集
2. FTPでyield.hashpilot.infoにアップロード

### 機能
- **月選択プルダウン**: 全期間（11/1〜）/ 2025年12月 / 2025年11月...
- **統計カード**:
  - 総レコード数
  - プラス日数
  - マイナス日数
  - 選択期間合計（月別選択時はその月の合計）
  - TOTAL（11/1〜）（常に全期間の累積）
- **テーブル**: 日付とユーザー受取率(%)を表示

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

## 🚧 未対応タスク

### 月末出金に紹介報酬を含める修正 ✅ 完了

**実装済み（2025年12月17日）:**
- ✅ `affiliate_cycle.withdrawn_referral_usdt`カラム追加
- ✅ `monthly_withdrawals.personal_amount`/`referral_amount`カラム追加
- ✅ `process_monthly_withdrawals`関数修正（USDTフェーズなら紹介報酬も含める）
- ✅ `complete_withdrawals_batch`関数修正（withdrawn_referral_usdtも更新）
- ✅ 管理画面にフェーズ（USDT/HOLD）表示追加

**SQLスクリプト:** `scripts/FIX-withdrawal-include-referral.sql`

**仕様:**
- USDTフェーズ: 個人利益 + 紹介報酬を出金可能
- HOLDフェーズ: 個人利益のみ出金可能（紹介報酬は次のNFT付与待ち）
- 出金可能な紹介報酬 = `cum_usdt - withdrawn_referral_usdt`

**手動対応履歴:**
- 2025年11月分: 手動で紹介報酬を計算し、個人利益と合算して送金済み

### 休眠（解約）ユーザーのUI対応 ✅ 完了

**実装済み（2025年12月）:**
- ✅ ダッシュボードに解約バナー表示（`DormantUserBanner`コンポーネント）
- ✅ NFT購入ページをアクセス不可に（`app/nft/page.tsx`）
- ✅ 紹介リンクを無効化（`app/profile/page.tsx`）
- ✅ 紹介報酬カード・組織図・レベル別統計を非表示（`app/dashboard/page.tsx`）
- ✅ 管理画面に「解約済み」バッジ表示（`app/admin/users/page.tsx`）

**判定条件:** `is_active_investor === false && has_approved_nft === true`

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

### 🚧 未対応: 却下メールの文言修正

**ファイル:** `supabase/functions/send-coinw-rejection-email/index.ts`

**現在の文言:**
- 件名: 【HASHPILOT】CoinW UID変更申請が却下されました
- ヘッダー: CoinW UID変更申請が却下されました / 申請内容をご確認の上、再度お申し込みください。
- 申請内容: ユーザーID、変更前/申請したCoinW UID、却下日時
- 却下理由: （管理者入力時のみ表示）
- 再申請案内: 正しいCoinW UIDをご確認の上、プロフィールページから再度申請してください。
- ボタン: プロフィールページで再申請 / サポートLINE

**修正依頼が来たら:** Edge Functionを更新してデプロイする必要あり

---

最終更新: 2025年12月23日

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

### NFT重複・不整合の修正履歴（2025年12月23日）

**修正対象ユーザー:**
| ユーザーID | 問題 | 修正内容 |
|------------|------|----------|
| CA7902 | NFT2枚（購入は1枚） | 重複NFT削除 |
| 0E0171 | NFT2枚（購入は1枚） | 重複NFT削除 |
| 3194C4 | 解約済みだがtotal_purchases残存 | フラグ修正 |
| 4CE189 | テストアカウント | 完全削除 |
| 794682 | NFT1枚（購入記録なし） | NFT削除・フラグ修正 |

**原因:** 2025年10月7日のマイグレーション時にNFTが重複作成された

**関連スクリプト:**
- `scripts/CHECK-nft-mismatch-users.sql` - 不整合調査
- `scripts/FIX-nft-mismatch-users.sql` - 不整合修正

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

## 📬 管理者メール受信箱機能（2026年1月実装）

### 概要
`support@hashpilot.biz` 宛のメールを受信し、管理画面で閲覧・返信できる機能。

### 構成要素

**1. Cloudflare Email Worker**
- ファイル: `cloudflare-workers/email-receiver/worker.js`
- 役割: `support@hashpilot.biz` 宛メールを受信してSupabaseに保存
- UTF-8デコード対応（Base64, Quoted-Printable）
- 送信者名・メールアドレスの分離パース

**2. データベーステーブル**
- `received_emails`: 受信メール保存
  - `from_email`, `from_name`: 送信者情報
  - `subject`, `body_text`, `body_html`: メール内容
  - `is_read`, `is_replied`: ステータス管理

**3. RPC関数**
- `save_received_email()`: Workerからメール保存
- `get_received_emails()`: 管理者用受信一覧取得
- `mark_received_email_as_read()`: 既読設定

### 管理画面機能 (`/admin/emails`)

**受信箱タブ:**
- 受信メール一覧表示（未読/既読フィルター）
- メール詳細モーダル（HTML本文表示対応）
- 削除機能
- 返信機能

**送信元アドレス選択:**
- `noreply@send.hashpilot.biz`: システム通知用（返信不可）
- `support@hashpilot.biz`: サポート用（返信可能）

### 返信機能

**HTMLメール形式:**
```html
<div style="font-family: ...">
  <p>[返信本文]</p>
  <hr>
  <p style="color: #666;">日時 送信者 wrote:</p>
  <blockquote style="border-left: 3px solid #ccc;">
    [元メール本文]
  </blockquote>
  <hr>
  <p>--<br>HASH PILOT NFT<br>https://hashpilot.net</p>
</div>
```

**処理フロー:**
1. `system_emails` テーブルにHTML本文を保存
2. `email_recipients` に送信先を登録
3. `send-system-email` Edge Functionで送信
4. `received_emails` の `is_replied` を `true` に更新

### Cloudflare設定

**Email Routing:**
1. Cloudflare Dashboard → Email → Email Routing
2. Email Workers で `hashpilot-email-receiver` を作成
3. `support@hashpilot.biz` をWorkerにルーティング

**Worker環境変数:**
- `SUPABASE_URL`: Supabase URL
- `SUPABASE_SERVICE_KEY`: Service Role Key

### RLSポリシー

```sql
-- 管理者のみ受信メール閲覧可能
CREATE POLICY "管理者のみ受信メール閲覧可能" ON received_emails
FOR SELECT USING (
  is_admin((auth.jwt() ->> 'email'::text), auth.uid())
);

-- 管理者のみ受信メール削除可能
CREATE POLICY "管理者のみ受信メール削除可能" ON received_emails
FOR DELETE USING (
  is_admin((auth.jwt() ->> 'email'::text), auth.uid())
);
```

### 関連ファイル

- `cloudflare-workers/email-receiver/worker.js` - メール受信Worker
- `app/admin/emails/page.tsx` - 管理画面（送受信）
- `scripts/ADD-email-inbox-feature.sql` - DB設定スクリプト
- `supabase/functions/send-system-email/index.ts` - メール送信Edge Function

### トラブルシューティング

**文字化け:**
- Worker内の `decodeUtf8()`, `decodeQuotedPrintable()` でUTF-8デコード
- `Content-Transfer-Encoding` に応じて処理

**メールが届かない:**
1. Cloudflare Email Routingの設定確認
2. Worker環境変数（SUPABASE_URL, SUPABASE_SERVICE_KEY）確認
3. Workerログでエラー確認

**返信がプレーンテキスト:**
- HTMLをインラインスタイルで作成
- Edge Functionが `html` フィールドで送信

---

## 🔒 外部プロジェクト使用テーブル（編集禁止）

以下のテーブルは外部プロジェクト（hashokx）で使用しています。HASHPILOTでは一切触らないでください。

| テーブル名 | 使用プロジェクト | 用途 |
|------------|------------------|------|
| user_api_keys | hashokx | ユーザーのOKX APIキー管理 |

**注意:** これらのテーブルはHASHPILOTの機能とは無関係です。誤って編集・削除しないでください。

---

最終更新: 2026年1月9日