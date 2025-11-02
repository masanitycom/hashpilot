# 日利率の精度確認結果

## 確認日
2025年11月2日

## 確認内容
日利率が小数点第3位（1.000%形式）まで正しく入力・計算・保存されるか

## 確認結果

### 1. フロントエンド入力（✅ 対応済み）
**ファイル:** `app/admin/yield/page.tsx`

```typescript
<Input
  type="number"
  step="0.001"  // ← 小数点第3位まで入力可能
  value={yieldRate}
  ...
/>
```

**入力例:**
- `1.234` → 1.234%
- `0.123` → 0.123%
- `-0.456` → -0.456%

### 2. JavaScript計算（✅ 対応済み）
**ファイル:** `app/admin/yield/page.tsx` (Line 62-76)

```typescript
const yield_rate = Number.parseFloat(yieldRate) || 0  // 任意精度
const margin_rate = Number.parseFloat(marginRate) || 0
const after_margin = yield_rate * (1 - margin_rate / 100)
const calculated_user_rate = after_margin * 0.6
```

**計算例:**
```
入力: 1.234%
→ parseFloat: 1.234
→ / 100: 0.01234
→ × 0.7: 0.008638
→ × 0.6: 0.0051828
→ 表示: 0.518% (toFixed(3))
```

JavaScriptのNumber型は64bit浮動小数点数（IEEE 754）で、約15桁の有効数字を持つため、小数点第3位程度は余裕で表現可能。

### 3. データベース保存（✅ 対応済み）
**テーブル:** `daily_yields`

```sql
yield_rate NUMERIC     -- 精度指定なし = 任意精度
margin_rate NUMERIC    -- 精度指定なし = 任意精度
user_rate NUMERIC      -- 精度指定なし = 任意精度
```

PostgreSQLの`NUMERIC`型（精度指定なし）は：
- **任意の精度**を持つ
- 内部的には可変長の10進数表現
- 小数点第3位どころか、数百桁でも保存可能

**確認方法:**
```sql
-- scripts/test-yield-precision.sql を実行
-- または
SELECT 1.234::NUMERIC;  -- → 1.234
SELECT 0.001234::NUMERIC;  -- → 0.001234
```

### 4. RPC関数処理（✅ 対応済み）
**関数:** `process_daily_yield_with_cycles`

```sql
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_yield_rate NUMERIC,  -- ← 任意精度
    p_margin_rate NUMERIC,
    ...
)
```

関数内の計算も`NUMERIC`型で行われるため、精度は保たれる。

## 結論

✅ **小数点第3位（1.000%形式）まで完全に対応しています**

### 実際の動作フロー
```
フロントエンド入力: 1.234%
↓
JavaScript計算: 1.234 → 0.01234 → 0.0051828
↓
RPC関数送信: 0.0051828 (NUMERIC)
↓
データベース保存: 0.0051828
↓
表示: 0.518% (toFixed(3))
```

## 注意事項

1. **入力フィールド**
   - `step="0.001"` なので、上下ボタンで0.001刻みで変更可能
   - 手入力ならさらに細かい桁数も入力可能（例: 1.23456%）

2. **表示精度**
   - `toFixed(3)` で小数点第3位まで表示
   - より細かい桁数が必要な場合は `toFixed(6)` などに変更可能

3. **データベース**
   - `NUMERIC`型は任意精度なので、変更不要
   - より厳密に制限したい場合は `NUMERIC(10,3)` に変更可能
     （`scripts/ensure-yield-precision.sql` を実行）

## テスト方法

### 手動テスト
1. https://hashpilot.net/admin/yield にアクセス
2. 日利率に `1.234` と入力
3. ユーザー受取率が `0.518%` と表示されることを確認
4. 送信して保存
5. データベースで確認:
   ```sql
   SELECT date, yield_rate, user_rate
   FROM daily_yields
   ORDER BY date DESC
   LIMIT 1;
   ```

### 自動テスト
```bash
# Supabase SQL Editorで実行
cat scripts/test-yield-precision.sql
```

## 更新履歴
- 2025/11/02: 小数点第3位対応確認・ドキュメント作成
