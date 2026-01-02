# 12月 available_usdt 過剰問題の原因と対応

## 問題の概要

12月開始ユーザー（operation_start_date >= 2025-12-01）の`available_usdt`が実際より過大になっていた。

**例:**
| ユーザー | 修正前 | 正しい値 | 過剰額 |
|----------|--------|----------|--------|
| ACACDB | $972.35 | $493.91 | $478.44 |
| 264B91 | $925.96 | $458.80 | $467.16 |
| 1NFTユーザー多数 | $47.32 | $23.41 | $23.91 |

---

## 原因

### 月次紹介報酬が2回処理された

**証拠:**
```
user_referral_profit_monthly テーブル:
- 2025-12-01 13:12:31 処理: 839件、$8,365.94
- 2026-01-01 03:40:57 処理: 979件、$7,788.04
```

**同一ユーザーに2回の紹介報酬が記録:**
```
user_id: 04161E → 12/1と1/1の両方で処理
user_id: 07712F → 12/1と1/1の両方で処理（143件）
... 他多数
```

**発生メカニズム:**
1. **12月1日**: 月次紹介報酬処理が実行され、`available_usdt`に加算
2. **1月1日**: 再度月次紹介報酬処理が実行され、`available_usdt`に**再度加算**
3. 結果として、紹介報酬分が二重に`available_usdt`に反映

---

## なぜ日利は正常だったか

日利処理（`process_daily_yield_v2`）は**日付ごとに1回のみ**実行され、重複チェックも機能していた。

紹介報酬なしユーザーの検証:
```
ACBFBA: available_usdt $1,989.68 = daily_profit $1,989.68 ✓
DEF010: available_usdt $397.94 = daily_profit $397.94 ✓
```

---

## 修正内容

### 実行済み: FIX-december-start-users-available-usdt.sql

```sql
UPDATE affiliate_cycle ac
SET available_usdt = COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0)
FROM users u
LEFT JOIN (日利合計) dp ON ...
LEFT JOIN (紹介報酬合計) rp ON ...
WHERE u.operation_start_date >= '2025-12-01'
  AND 差額 > 1;
```

**修正結果:**
- 54名のユーザーの`available_usdt`を正しい値に修正
- `monthly_withdrawals.total_amount`も連動して修正
- 12月出金統計: 357件、$32,613.74

---

## 今後の対策

### 1. 月次紹介報酬処理の重複防止

現在の`user_referral_profit_monthly`テーブルには重複チェックがない。
以下のいずれかを実装すべき:

**オプションA: ユニーク制約を追加**
```sql
ALTER TABLE user_referral_profit_monthly
ADD CONSTRAINT unique_monthly_referral
UNIQUE (user_id, year, month, referral_level, child_user_id);
```

**オプションB: 処理前に既存データを削除**
```sql
-- 月次紹介報酬処理の最初に
DELETE FROM user_referral_profit_monthly
WHERE year = v_year AND month = v_month;
```

### 2. available_usdt整合性チェックの定期実行

月末処理前に以下のSQLで不整合を検出:

```sql
SELECT user_id, available_usdt,
  (日利合計 + 紹介報酬合計) as expected,
  available_usdt - expected as diff
FROM affiliate_cycle
WHERE ABS(diff) > 1;
```

---

## 関連ファイル

- `scripts/FIX-december-start-users-available-usdt.sql` - 修正SQL
- `scripts/CHECK-all-users-available-usdt-mismatch.sql` - 不整合チェック
- `scripts/INVESTIGATE-over-amount-pattern.sql` - 原因調査

---

**作成日:** 2026-01-01
**作成者:** Claude Code
