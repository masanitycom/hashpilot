# V2システム移行計画

## 概要

V1システム（利率％入力）からV2システム（金額$入力）への移行計画

---

## 🔍 現状分析

### V1システム（現在使用中）
- **入力方式**: 利率％（yield_rate, margin_rate）
- **RPC関数**: `process_daily_yield_with_cycles`
- **ログテーブル**: `daily_yield_log`
- **ユーザー利益テーブル**: `user_daily_profit`（集計値）

### V2システム（準備完了）
- **入力方式**: 金額$（total_profit_amount）
- **RPC関数**: `process_daily_yield_v2`
- **ログテーブル**: `daily_yield_log_v2`
- **ユーザー利益テーブル**: なし（`nft_daily_profit`から計算）

---

## ⚠️ 重要な違い

### 1. ユーザーダッシュボードの互換性

**V1が使用するテーブル:**
```sql
user_daily_profit  -- V1が作成・更新（ユーザー別の集計値）
nft_daily_profit   -- V1が作成（NFT別の詳細）
user_referral_profit -- V1が作成（紹介報酬）
```

**V2が使用するテーブル:**
```sql
-- user_daily_profitは作成しない ❌
nft_daily_profit   -- V2が作成（NFT別の詳細）✅
user_referral_profit -- V2が作成（紹介報酬）✅
```

### 2. 問題点

**ユーザーダッシュボードのコンポーネントが`user_daily_profit`に依存:**
- `daily-profit-card.tsx` - 昨日の確定日利
- `monthly-profit-card.tsx` - 今月の累積利益
- `monthly-cumulative-profit-card.tsx` - 月次累積
- その他のグラフコンポーネント

**V2に移行すると`user_daily_profit`が更新されず、ダッシュボードが壊れる！**

---

## ✅ 解決策

### オプション1: V2にuser_daily_profit作成を追加（推奨）

**メリット:**
- ✅ ユーザーダッシュボードの変更不要
- ✅ 既存の表示ロジックがそのまま動く
- ✅ 移行がスムーズ

**デメリット:**
- ❌ V2関数を修正する必要がある

**実装:**
V2の`process_daily_yield_v2`関数に以下を追加：

```sql
-- STEP 4の後に追加
-- user_daily_profitにユーザー別集計を記録
INSERT INTO user_daily_profit (
  user_id,
  date,
  daily_profit,
  base_amount,
  user_rate,
  created_at
)
SELECT
  u.user_id,
  p_date,
  SUM(ndp.daily_profit) as daily_profit,
  1000.0 as base_amount,
  (SUM(ndp.daily_profit) / (COUNT(ndp.id) * 1000.0)) * 100 as user_rate,
  NOW()
FROM users u
JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE ndp.date = p_date
GROUP BY u.user_id
ON CONFLICT (user_id, date) DO UPDATE
SET
  daily_profit = EXCLUDED.daily_profit,
  user_rate = EXCLUDED.user_rate,
  updated_at = NOW();
```

---

### オプション2: ダッシュボードをnft_daily_profitベースに変更

**メリット:**
- ✅ V2関数の変更不要
- ✅ データの二重管理を避けられる

**デメリット:**
- ❌ ユーザーダッシュボードの全コンポーネント修正が必要
- ❌ テスト工数が大きい
- ❌ リスクが高い

**変更が必要なファイル:**
- `components/daily-profit-card.tsx`
- `components/monthly-profit-card.tsx`
- `components/monthly-cumulative-profit-card.tsx`
- `components/daily-profit-chart.tsx`
- その他複数のコンポーネント

---

## 📋 推奨：オプション1の実装手順

### STEP 1: V2関数にuser_daily_profit作成を追加

1. `scripts/FIX-process-daily-yield-v2-add-user-daily-profit.sql`を作成
2. V2関数を修正してuser_daily_profitを作成
3. 本番環境に適用

### STEP 2: テスト環境で検証

1. V2関数でテスト日利を入力
2. `user_daily_profit`が正しく作成されるか確認
3. ユーザーダッシュボードで表示確認

### STEP 3: 管理画面UIの更新

**現在の管理画面（V1専用）:**
```tsx
// app/admin/yield/page.tsx
const { data, error } = await supabase.rpc("process_daily_yield_with_cycles", {
  p_date: date,
  p_yield_rate: yieldValue,
  p_margin_rate: marginValue,
  p_is_test_mode: false,
  p_skip_validation: false
})
```

**V2対応版:**
```tsx
// 金額入力フィールドを追加
const [totalProfitAmount, setTotalProfitAmount] = useState("")

// V2 RPC呼び出し
const { data, error } = await supabase.rpc("process_daily_yield_v2", {
  p_date: date,
  p_total_profit_amount: parseFloat(totalProfitAmount),
  p_is_test_mode: false
})
```

### STEP 4: 日利削除機能の更新

**V1の削除処理:**
```tsx
// daily_yield_log, user_daily_profit, nft_daily_profit, user_referral_profitを削除
```

**V2の削除処理:**
```tsx
// daily_yield_log_v2, user_daily_profit, nft_daily_profit, user_referral_profitを削除
```

### STEP 5: 本番環境での移行

1. V2関数を更新（user_daily_profit作成追加）
2. 管理画面UIをV2対応に更新
3. 12/2以降の日利入力からV2を使用
4. V1関数は残す（過去データの再計算用）

---

## 🔄 V1とV2の機能比較

| 機能 | V1 | V2 |
|------|----|----|
| 入力方式 | 利率％ | 金額$ |
| 個人利益配布 | ✅ | ✅ |
| 紹介報酬（Level 1-3） | ✅ | ✅ |
| NFT自動付与 | ✅ | ✅ |
| 月末処理統合 | ✅ | ✅ |
| user_daily_profit作成 | ✅ | ❌→✅（修正予定） |
| マイナス日利対応 | ✅ | ✅ |

---

## 📝 移行後の運用

### V1システム（残す理由）
- 過去データの再計算に使用
- バックアップとして保持
- 緊急時のフォールバック

### V2システム（メイン）
- 12/2以降の日利入力に使用
- 金額ベースでの運用
- より直感的な入力方式

---

## ⏰ タイムライン

### 11/30（今日）
- ✅ V2テーブル作成完了
- ✅ V2 RPC関数作成完了
- 🔄 V2関数修正（user_daily_profit追加）← **これから**

### 12/1（明日）
- V1で11/30の日利入力（月末処理テスト）
- 月次紹介報酬計算の自動実行確認
- 月末自動出金の動作確認

### 12/2（月末テスト成功後）
- V2関数の最終修正を本番適用
- 管理画面UIをV2対応に更新
- V2での最初の日利入力
- ユーザーダッシュボード動作確認

---

## 🚨 注意事項

1. **V1とV2は別のログテーブルを使用**
   - V1: `daily_yield_log`
   - V2: `daily_yield_log_v2`
   - 両方のログが残るため、履歴管理に注意

2. **user_daily_profitは共通**
   - V1もV2も同じテーブルに書き込む
   - 重複書き込みの防止が必要（UPSERT使用）

3. **月末処理は1回のみ実行**
   - V1とV2で二重実行しないよう注意
   - どちらか一方のシステムのみ使用

4. **管理画面の切り替え**
   - V2移行後はV2のみ使用
   - V1は削除機能でのみ使用（過去データ修正用）

---

## 🔍 次のアクション

1. **V2関数の修正**（最優先）
   - `user_daily_profit`作成を追加
   - テスト環境で検証

2. **管理画面UI更新**
   - 金額入力フィールド追加
   - V2 RPC呼び出しに変更

3. **削除機能の更新**
   - V2対応の削除処理を追加

4. **ドキュメント更新**
   - CLAUDE.mdにV2システムの説明を追加
   - 運用マニュアル更新
