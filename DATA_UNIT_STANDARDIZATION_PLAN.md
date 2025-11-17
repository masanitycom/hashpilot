# データ単位統一計画

## 🎯 目的

「1つ修正すると色んなところが壊れてしまう」問題を根本的に解決する。

## 🐛 現在の問題

### 現状の混在状態

| データ | RPC関数での扱い | DB格納形式 | フロントエンド表示 | 問題 |
|--------|----------------|-----------|-----------------|------|
| yield_rate | パーセント値（0.535） | パーセント値（0.535） | `× 1` で 0.535% | ❌ 不統一 |
| margin_rate | デシマル値（0.30） | パーセント値（30） | `× 1` で 30% | ❌ 変換あり |
| user_rate | パーセント値（0.2247） | **パーセント or デシマル** | `× 100` で 0.2247% | ❌❌ 混在 |

### 具体的な不具合

**例1: 2025/11/16のデータ**
- 設定: 日利率 0.520%, マージン率 0%
- 期待値: ユーザー利率 = 0.520 × 1.0 × 0.6 = **0.312%**
- 実際の表示: **21.840%** ← 約70倍の誤差！

**原因分析:**
```typescript
// 管理画面（app/admin/yield/page.tsx 987行目）
{(Number.parseFloat(item.user_rate) * 100).toFixed(3)}%
```

DBに格納されている値が `0.21840` （デシマル形式？）なら：
- 表示 = 0.21840 × 100 = 21.840%

しかし、正しい計算結果は：
- 0.520 × 1.0 × 0.6 = 0.312 （パーセント値）
- または 0.00312 （デシマル値）

---

## ✅ 解決策：デシマル形式への完全統一

### 統一後のルール

**すべての率をデシマル形式で統一:**

| データ | 入力 | RPC関数 | DB格納 | フロントエンド表示 |
|--------|------|---------|--------|------------------|
| yield_rate | 0.535% | 0.00535 | 0.00535 | `× 100` → 0.535% |
| margin_rate | 30% | 0.30 | 0.30 | `× 100` → 30% |
| user_rate | - | 0.002247 | 0.002247 | `× 100` → 0.2247% |

### 利点

1. **データベースとフロントエンドが完全一致**
   - DBに格納される値 = 計算で使う値
   - 表示時は常に `× 100` でパーセント表示

2. **計算の透明性**
   ```sql
   v_user_rate := p_yield_rate * (1.0 - p_margin_rate) * 0.6;
   -- 0.00535 * (1.0 - 0.30) * 0.6 = 0.002247
   ```

3. **エラーの最小化**
   - すべて同じ単位なので、変換ミスがない
   - デバッグが容易

---

## 📋 実装計画

### STEP 1: RPC関数の修正

**現在の関数:**
```sql
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
  p_date DATE,
  p_yield_rate NUMERIC,  -- パーセント値（0.535）
  p_margin_rate NUMERIC, -- デシマル値（0.30）
  ...
) ...
BEGIN
  -- 計算
  v_personal_profit_per_nft := (1000.0 * p_yield_rate / 100.0) * (1.0 - p_margin_rate) * 0.6;
  v_user_rate := p_yield_rate * (1.0 - p_margin_rate) * 0.6; -- ← パーセント値
```

**修正後の関数:**
```sql
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
  p_date DATE,
  p_yield_rate NUMERIC,  -- デシマル値（0.00535）
  p_margin_rate NUMERIC, -- デシマル値（0.30）
  ...
) ...
BEGIN
  -- 計算
  v_personal_profit_per_nft := (1000.0 * p_yield_rate) * (1.0 - p_margin_rate) * 0.6;
  v_user_rate := p_yield_rate * (1.0 - p_margin_rate) * 0.6; -- ← デシマル値
```

**変更点:**
- `p_yield_rate / 100.0` → `p_yield_rate` （すでにデシマル）
- `p_yield_rate` → `p_yield_rate` （user_rateもデシマルで格納）

---

### STEP 2: 管理画面の修正

**app/admin/yield/page.tsx**

**現在のコード（278-296行目）:**
```typescript
const yieldValue = Number.parseFloat(yieldRate)  // パーセント値そのまま
const marginValue = Number.parseFloat(marginRate) / 100  // デシマルに変換

const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_with_cycles', {
  p_date: date,
  p_yield_rate: yieldValue,      // 0.535
  p_margin_rate: marginValue,    // 0.30
  ...
})
```

**修正後:**
```typescript
const yieldValue = Number.parseFloat(yieldRate) / 100  // デシマルに変換
const marginValue = Number.parseFloat(marginRate) / 100  // デシマルに変換

const { data: rpcResult, error: rpcError } = await supabase.rpc('process_daily_yield_with_cycles', {
  p_date: date,
  p_yield_rate: yieldValue,      // 0.00535
  p_margin_rate: marginValue,    // 0.30
  ...
})
```

**履歴表示（976, 979, 987行目）:**

**現在のコード:**
```typescript
{Number.parseFloat(item.yield_rate).toFixed(3)}%  // パーセント値として表示
{Number.parseFloat(item.margin_rate).toFixed(0)}%  // パーセント値として表示
{(Number.parseFloat(item.user_rate) * 100).toFixed(3)}%  // デシマル → パーセント
```

**修正後:**
```typescript
{(Number.parseFloat(item.yield_rate) * 100).toFixed(3)}%  // デシマル → パーセント
{(Number.parseFloat(item.margin_rate) * 100).toFixed(0)}%  // デシマル → パーセント
{(Number.parseFloat(item.user_rate) * 100).toFixed(3)}%  // デシマル → パーセント（変更なし）
```

---

### STEP 3: yield.hashpilot.info の確認

https://yield.hashpilot.info/ のコードを確認し、同様に修正する必要があるか確認。

---

### STEP 4: 既存データの修正

**問題のあるデータを特定:**
```sql
-- user_rateが異常な値のレコードを確認
SELECT
  date,
  yield_rate,
  margin_rate,
  user_rate,
  -- 期待される正しい値（デシマル形式）
  (yield_rate / 100.0) * (1.0 - margin_rate / 100.0) * 0.6 as expected_user_rate_decimal,
  -- 差分
  user_rate - ((yield_rate / 100.0) * (1.0 - margin_rate / 100.0) * 0.6) as difference
FROM daily_yield_log
WHERE ABS(user_rate - ((yield_rate / 100.0) * (1.0 - margin_rate / 100.0) * 0.6)) > 0.0001
ORDER BY date DESC;
```

**修正スクリプト:**
```sql
-- すべてのuser_rateを正しいデシマル値に修正
UPDATE daily_yield_log
SET user_rate = (yield_rate / 100.0) * (1.0 - margin_rate / 100.0) * 0.6
WHERE user_rate IS NOT NULL;

-- yield_rateとmargin_rateもデシマル形式に変換
UPDATE daily_yield_log
SET
  yield_rate = yield_rate / 100.0,
  margin_rate = margin_rate / 100.0;
```

**⚠️ 重要:** この修正は全データに影響するため、**必ずバックアップを取ってから実行**すること。

---

## 🧪 テスト計画

### テストケース

| 入力（管理画面） | RPC関数受取 | 計算結果（user_rate） | DB格納値 | 表示 |
|-----------------|------------|---------------------|---------|------|
| 日利率: 0.535% | 0.00535 | 0.002247 | 0.002247 | 0.225% ✅ |
| 日利率: -0.2% | -0.002 | -0.00084 | -0.00084 | -0.084% ✅ |
| マージン率: 30% | 0.30 | （上記計算） | （上記） | 30% ✅ |
| マージン率: 0% | 0.00 | 0.00312 | 0.00312 | 0.312% ✅ |

---

## 📅 実装スケジュール

1. **STEP 1:** RPC関数修正 + テスト環境で動作確認
2. **STEP 2:** 管理画面修正 + テスト環境で動作確認
3. **STEP 3:** yield.hashpilot.info 確認・修正
4. **STEP 4:** 既存データ修正スクリプト作成・確認
5. **本番適用:** 深夜に一括実行（ユーザーへの影響最小化）

---

## 🔍 確認事項

- [ ] RPC関数の修正完了
- [ ] 管理画面の修正完了
- [ ] yield.hashpilot.info の確認完了
- [ ] 既存データの修正スクリプト作成完了
- [ ] テスト環境での動作確認完了
- [ ] 本番環境へのデプロイ完了
- [ ] 既存データの修正完了
- [ ] 表示の整合性確認完了

---

最終更新: 2025年11月17日
