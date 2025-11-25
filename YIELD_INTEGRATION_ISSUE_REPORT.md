# 日利設定とユーザーダッシュボードの整合性問題レポート

**日付**: 2025-11-12
**ステータス**: ❌ 緊急対応が必要
**影響範囲**: 全ユーザーのダッシュボード表示

---

## 📋 問題の概要

管理画面（`https://hashpilot-staging.vercel.app/admin/yield`）で日利を設定しても、ユーザーダッシュボードに利益が表示されない問題が発生しています。

### 確認された症状

1. **管理画面の表示**（2025/11/9の例）:
   - 運用利益: $6,824.41（プラス）
   - 顧客累積利益: **$-5,352.59**（❌ マイナス）
   - 累積手数料: $0.00
   - 当日利益: $-5,352.59（❌ マイナス）

2. **ユーザーダッシュボード**:
   - 「昨日の確定日利」が表示されない
   - 個人投資利益が$0
   - グラフにデータが反映されない

---

## 🔍 根本原因の特定

### 1. 累積計算がマイナスになっている

`daily_yield_log_v2`テーブルの累積データ：

```sql
cumulative_gross_profit < 0  -- 手数料前の累積がマイナス
↓
cumulative_fee = 0            -- 手数料が0（GREATEST関数により）
↓
cumulative_net_profit < 0     -- 顧客累積利益もマイナス
↓
daily_pnl < 0                 -- 当日確定利益がマイナス
```

### 2. 配当が0になる

`process_daily_yield_v2` RPC関数の処理：

```sql
IF v_daily_pnl > 0 THEN
    v_distribution_dividend := v_daily_pnl * 0.60;  -- 配当60%
    v_distribution_affiliate := v_daily_pnl * 0.30; -- 紹介30%
    v_distribution_stock := v_daily_pnl * 0.10;     -- ストック10%
ELSE
    -- ❌ マイナスの場合は全て0
    v_distribution_dividend := 0;
    v_distribution_affiliate := 0;
    v_distribution_stock := 0;
END IF;
```

### 3. ユーザーデータが作成されない

配当が0の場合：

```sql
IF v_distribution_dividend > 0 THEN
    -- ✅ プラスの場合のみループ実行
    FOR v_user_record IN ... LOOP
        INSERT INTO nft_daily_profit (...) VALUES (...);
    END LOOP;
ELSE
    -- ❌ 0の場合はスキップされる
    -- → nft_daily_profitにレコードが作成されない
END IF;
```

### 4. ビューが空になる

```sql
-- user_daily_profitはビュー（nft_daily_profitから集計）
CREATE OR REPLACE VIEW user_daily_profit AS
SELECT
    user_id,
    date,
    SUM(daily_profit) as daily_profit,  -- ← レコードがない = 空
    ...
FROM nft_daily_profit
GROUP BY user_id, date;
```

### 5. ダッシュボードに表示されない

```typescript
// components/daily-profit-card.tsx
const { data: profitData } = await supabase
  .from('user_daily_profit')  // ← ビューが空
  .select('daily_profit')
  .eq('user_id', userId)
  .eq('date', yesterdayStr)

// profitData = null → 表示されない
```

---

## 💡 なぜ累積がマイナスになったのか？

過去の日利設定で、以下のような操作があったと推測されます：

1. **テストモードでの大きなマイナス設定**
2. **誤って大きなマイナス値を入力**
3. **データの削除・再設定時の累積リセット漏れ**

---

## 🛠 修正方法

### 【推奨】方法A: 全データをリセットして再計算

```sql
-- 1. バックアップ作成
CREATE TABLE daily_yield_log_v2_backup AS SELECT * FROM daily_yield_log_v2;
CREATE TABLE nft_daily_profit_backup AS SELECT * FROM nft_daily_profit;

-- 2. 指定期間のデータを削除
DELETE FROM stock_fund WHERE date >= '2025-11-01';
DELETE FROM user_referral_profit WHERE date >= '2025-11-01';
DELETE FROM nft_daily_profit WHERE date >= '2025-11-01';
DELETE FROM daily_yield_log_v2 WHERE date >= '2025-11-01';

-- 3. 管理画面で日利を再設定
-- ※ 正しい運用利益の値を各日付ごとに再入力
```

### 方法B: 部分的に再計算

累積がマイナスになった日以降のみ削除して再設定：

```sql
-- 累積がマイナスになった最初の日を特定
SELECT MIN(date) FROM daily_yield_log_v2 WHERE cumulative_gross_profit < 0;

-- その日以降を削除
DELETE FROM ... WHERE date >= '特定した日付';

-- 管理画面で再設定
```

### 方法C: オフセット調整（応急処置）

```sql
-- 累積にオフセット値を加算してプラスにする
-- ※ 根本的な解決ではないため推奨しません
UPDATE daily_yield_log_v2
SET cumulative_gross_profit = cumulative_gross_profit + 10000;
```

---

## 📝 修正手順（推奨）

### 1. 現状確認

```bash
# Supabase SQL Editorで実行
SELECT * FROM scripts/check-yield-data-integrity.sql;
```

### 2. バックアップ作成

```sql
-- scripts/FIX-cumulative-negative-issue.sql の選択肢A-1を実行
CREATE TABLE daily_yield_log_v2_backup AS SELECT * FROM daily_yield_log_v2;
CREATE TABLE nft_daily_profit_backup AS SELECT * FROM nft_daily_profit;
```

### 3. データ削除

```sql
-- scripts/FIX-cumulative-negative-issue.sql の選択肢A-2を実行
DELETE FROM stock_fund WHERE date >= '2025-11-01';
DELETE FROM user_referral_profit WHERE date >= '2025-11-01';
DELETE FROM nft_daily_profit WHERE date >= '2025-11-01';
DELETE FROM daily_yield_log_v2 WHERE date >= '2025-11-01';
```

### 4. 日利を再設定

管理画面（`/admin/yield`）で各日の日利を再設定：

- 11/1: $xxx
- 11/2: $xxx
- ...（正しい値を入力）

### 5. 確認

```sql
-- 累積が正常になったか確認
SELECT
    date,
    cumulative_gross_profit,
    cumulative_net_profit,
    daily_pnl
FROM daily_yield_log_v2
ORDER BY date DESC;

-- ユーザーデータが作成されたか確認
SELECT COUNT(*) FROM nft_daily_profit WHERE date = '2025-11-09';
```

### 6. ユーザーダッシュボードで表示確認

- ダッシュボードにアクセス
- 「昨日の確定日利」が表示されることを確認
- グラフにデータが表示されることを確認

---

## ⚠️ 今後の予防策

### 1. 管理画面に警告を追加

累積がマイナスになる場合、警告メッセージを表示：

```typescript
// app/admin/yield/page.tsx
if (cumulative_net < 0) {
  setMessage({
    type: "warning",
    text: "⚠️ 警告: 累積がマイナスになります。配当は0になり、ユーザーダッシュボードに表示されません。"
  });
}
```

### 2. マイナス日でもレコード作成

マイナスの日でも`nft_daily_profit`に`daily_profit = 0`のレコードを作成するようRPC関数を修正：

```sql
-- process_daily_yield_v2を修正
-- v_distribution_dividend = 0の場合でもレコード作成
IF v_distribution_dividend <= 0 THEN
    -- マイナスの日もレコード作成（利益は0）
    FOR v_user_record IN ... LOOP
        INSERT INTO nft_daily_profit (...) VALUES (
            ...,
            0,  -- daily_profit = 0
            ...
        );
    END LOOP;
END IF;
```

### 3. 累積リセット機能の追加

管理画面に「累積をリセット」ボタンを追加して、簡単にリセットできるようにする。

---

## 📂 関連ファイル

### 調査・修正スクリプト

- `scripts/check-yield-data-integrity.sql` - データ整合性確認
- `scripts/FIX-cumulative-negative-issue.sql` - 修正スクリプト（選択肢付き）

### システムファイル

- `app/admin/yield/page.tsx` - 日利設定画面（line 296: `process_daily_yield_v2`呼び出し）
- `scripts/create-rpc-process-daily-yield-v2.sql` - RPC関数定義
- `scripts/fix-rpc-process-daily-yield-v2.sql` - RPC関数修正版
- `scripts/URGENT-fix-user-daily-profit.sql` - `user_daily_profit`ビュー定義

### フロントエンドコンポーネント

- `components/daily-profit-card.tsx` - 昨日の確定日利（line 42-47: データ取得）
- `components/personal-profit-card.tsx` - 個人投資利益
- `components/total-profit-card.tsx` - 合計利益

---

## ✅ まとめ

### 問題

- 過去の累積がマイナス → 配当が0 → `nft_daily_profit`にレコードなし → ユーザーダッシュボードに表示されない

### 解決策

1. **即座の対応**: データをリセットして日利を再設定（方法A推奨）
2. **長期的対応**: RPC関数を修正してマイナス日でもレコード作成
3. **予防**: 管理画面に警告メッセージを追加

### 次のステップ

1. `scripts/FIX-cumulative-negative-issue.sql`を実行
2. 管理画面で日利を再設定
3. ユーザーダッシュボードで表示を確認

---

**作成者**: Claude Code
**レビュー**: 要管理者確認
