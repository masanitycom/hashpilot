# ダッシュボード表示問題の解決策

**日付**: 2025-11-12
**ユーザー**: 7A9637
**問題**: ダッシュボードに昨日の利益が表示されない

---

## 🔍 問題の原因（確定）

### 1. 日利が設定されていない日がある

| 日付 | 日利設定 | ステータス |
|------|---------|-----------|
| 11/9 | ✅ 設定済み | 配当あり（$5.926） |
| 11/8 | ✅ 設定済み | 配当あり（$2.570） |
| **11/10** | **❌ 未設定** | **データなし** |
| **11/11** | **❌ 未設定** | **データなし** |

### 2. ダッシュボードは「昨日（11/11）」のデータを表示しようとしている

```typescript
// components/daily-profit-card.tsx (line 37-39)
const yesterday = new Date()
yesterday.setDate(yesterday.getDate() - 1)
const yesterdayStr = yesterday.toISOString().split('T')[0]  // 2025-11-11

// データベースクエリ
const { data: profitData } = await supabase
  .from('user_daily_profit')
  .eq('date', yesterdayStr)  // ← 11/11のデータを探す
  .maybeSingle()

// 結果: profitData = null （11/11の日利が未設定のため）
```

### 3. データがないため、すべてのカードで$0.000表示

- **DailyProfitCard**: `profitData = null` → $0.000
- **PersonalProfitCard**: `yesterdayData = null` → $0.000
- **TotalProfitCard**: `yesterdayData = null` → $0.000

---

## ✅ 解決方法

### 【方法1】欠けている日利を設定する（推奨）

管理画面（`/admin/yield`）で以下の日利を設定してください：

1. **2025-11-10の日利を設定**
   - 運用利益を入力（例: $3,000）
   - 「日利を設定」ボタンをクリック

2. **2025-11-11の日利を設定**
   - 運用利益を入力（例: $2,500）
   - 「日利を設定」ボタンをクリック

3. **ユーザーダッシュボードで確認**
   - ブラウザのキャッシュをクリア（Ctrl+Shift+R）
   - ダッシュボードにアクセス
   - 「昨日の確定日利」が表示されることを確認

### 【方法2】累積マイナス問題を解決してから設定

現在、累積がマイナスなので、プラスの日利を設定しても配当が0になる可能性があります。

**手順：**
1. `scripts/FIX-cumulative-negative-issue.sql`を実行（全データリセット）
2. 11/1から順に正しい日利を再設定
3. 累積がプラスになることを確認

---

## 🔧 根本的な修正（将来の改善）

### 問題: user_rateがNULLのため、DailyProfitCardで利率が表示されない

**現在のビュー定義：**
```sql
CREATE OR REPLACE VIEW user_daily_profit AS
SELECT
    user_id,
    date,
    SUM(daily_profit) AS daily_profit,
    MAX(yield_rate) AS yield_rate,
    NULL::numeric AS user_rate  -- ← 常にNULL！
FROM nft_daily_profit
GROUP BY user_id, date;
```

**修正案：**
```sql
CREATE OR REPLACE VIEW user_daily_profit AS
SELECT
    user_id,
    date,
    SUM(daily_profit) AS daily_profit,
    MAX(yield_rate) AS yield_rate,
    -- user_rateを計算（daily_profit / base_amount）
    CASE
        WHEN SUM(base_amount) > 0
        THEN SUM(daily_profit) / SUM(base_amount)
        ELSE NULL
    END AS user_rate,
    SUM(base_amount) AS base_amount
FROM nft_daily_profit
GROUP BY user_id, date;
```

しかし、**v2システムでは`user_rate`は不要**（配当分配方式に変更）のため、DailyProfitCardを修正する方が適切です。

### DailyProfitCardの修正案

```typescript
// components/daily-profit-card.tsx
// user_rateを使わずに、daily_profitのみ表示

setProfit(profitValue)
// ユーザー利率の代わりに、金額のみ表示
```

---

## 📝 まとめ

### 今すぐできること

1. **管理画面で11/10と11/11の日利を設定**
   - `/admin/yield`にアクセス
   - 各日付の運用利益を入力
   - データベースに反映されることを確認

2. **ユーザーダッシュボードで確認**
   - キャッシュクリア後に再読み込み
   - 「昨日の確定日利」が表示されることを確認

### 長期的な改善

1. **累積マイナス問題を解決**
   - `scripts/FIX-cumulative-negative-issue.sql`を実行
   - 全データをリセットして再設定

2. **DailyProfitCardをv2システムに対応**
   - `user_rate`依存を削除
   - `daily_profit`のみ表示するように変更

---

## 🔍 確認用クエリ

日利が正しく設定されたか確認：

```sql
-- 最近10日分の日利設定を確認
SELECT
    date,
    total_profit_amount,
    distribution_dividend,
    CASE
        WHEN distribution_dividend > 0 THEN '✅ 配当あり'
        ELSE '❌ 配当なし'
    END as status
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- 7A9637の最近の利益を確認
SELECT
    date,
    daily_profit,
    CASE
        WHEN daily_profit IS NOT NULL THEN '✅ データあり'
        ELSE '❌ データなし'
    END as status
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;
```

---

**作成者**: Claude Code
**レビュー**: 要管理者確認
