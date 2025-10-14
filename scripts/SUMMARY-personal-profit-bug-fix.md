# 個人配当計算バグの修正

## 問題の詳細

ユーザーからの報告:
> 個人配当だけなら大丈夫なのですが、報酬で自動購入されると個人の配当額が不具合出ていそうです

## 根本原因

`process_daily_yield_with_cycles()` 関数の **STEP 2** で個人配当を再計算していた:

```sql
-- 旧コード（バグあり）
v_base_amount := v_user_record.total_nft_count * 1000;
v_user_profit := v_base_amount * v_user_rate;
```

### 問題点

1. **二重計算**: STEP 1で既に各NFTの日利を計算して `nft_daily_profit` に保存済み
2. **タイミング問題**: STEP 3で自動NFTが追加されると、STEP 2の再計算ロジックとの整合性が取れない
3. **データ不整合**: `total_nft_count` は増えるが、新しいNFTの `nft_daily_profit` は今日分が存在しない

## 実行フロー（旧版）

```
STEP 1: 各NFT → nft_daily_profit に保存
  ├─ NFT #1: $1000 × 0.672% = $6.72
  ├─ NFT #2: $1000 × 0.672% = $6.72
  └─ 合計: $13.44

STEP 2: ユーザー集計（❌ 再計算）
  ├─ total_nft_count = 2
  ├─ v_base_amount = 2 × 1000 = $2000
  ├─ v_user_profit = $2000 × 0.672% = $13.44
  └─ available_usdt += $13.44 ✅

STEP 3: 自動購入（cum_usdt >= $2200）
  ├─ 新しいNFT #3 作成
  ├─ total_nft_count = 3 に更新
  └─ available_usdt += $1100

翌日の STEP 2（❌ バグ発生）
  ├─ total_nft_count = 3（前日の自動購入で増えた）
  ├─ v_base_amount = 3 × 1000 = $3000
  └─ v_user_profit = $3000 × 0.672% = $20.16 ❌

  でも STEP 1 の nft_daily_profit は:
  ├─ NFT #1: $6.72
  ├─ NFT #2: $6.72
  ├─ NFT #3: $6.72
  └─ 合計: $20.16 ✅

  → 結果的には合っているように見えるが...
```

### さらに複雑なケース

もしユーザーが **当日中に** 自動購入される場合:

```
STEP 1: NFT #1, #2 の日利計算
  └─ 合計: $13.44

STEP 2: ユーザー集計（❌ 再計算）
  └─ total_nft_count = 2 → available_usdt += $13.44

STEP 3: 自動購入
  ├─ NFT #3 作成（今日作成）
  ├─ total_nft_count = 3
  └─ available_usdt += $1100

問題: NFT #3 は今日作成されたので、今日の日利はゼロのはず
でも STEP 2 の再計算ロジックは total_nft_count しか見ていない
→ 翌日以降、不整合が発生する可能性
```

## 修正内容

STEP 2 で `nft_daily_profit` から直接集計する:

```sql
-- 新コード（修正後）
SELECT COALESCE(SUM(daily_profit), 0)
INTO v_user_profit
FROM nft_daily_profit
WHERE user_id = v_user_record.user_id
  AND date = p_date;
```

### メリット

1. ✅ **Single Source of Truth**: STEP 1 で計算したデータをそのまま使用
2. ✅ **自動購入と独立**: 新しいNFTは翌日から計算される（正しい挙動）
3. ✅ **データ整合性保証**: `nft_daily_profit` テーブルが唯一の真実の源

## 修正後のフロー

```
STEP 1: 各NFT → nft_daily_profit に保存
  ├─ NFT #1: $1000 × 0.672% = $6.72
  ├─ NFT #2: $1000 × 0.672% = $6.72
  └─ 合計: $13.44

STEP 2: ユーザー集計（✅ 集計のみ）
  ├─ SELECT SUM(daily_profit) FROM nft_daily_profit
  ├─ WHERE user_id = 'XXX' AND date = '2025-10-15'
  ├─ → $13.44（STEP 1 の結果をそのまま使用）
  └─ available_usdt += $13.44 ✅

STEP 3: 自動購入
  ├─ NFT #3 作成（今日作成、今日の日利なし）
  ├─ total_nft_count = 3
  └─ available_usdt += $1100

翌日の STEP 1:
  ├─ NFT #1: $6.72
  ├─ NFT #2: $6.72
  ├─ NFT #3: $6.72（翌日から計算開始）
  └─ 合計: $20.16

翌日の STEP 2:
  ├─ SELECT SUM(daily_profit) FROM nft_daily_profit
  └─ → $20.16 ✅（STEP 1 と完全一致）
```

## デプロイ手順

1. Supabase SQL Editor を開く
2. `/scripts/FIX-personal-profit-calculation-bug.sql` の内容を実行
3. 権限エラーが出る場合は、関数定義のみ実行（DO $$ブロックは省略可）

## 検証方法

```sql
-- テストモードで実行
SELECT * FROM process_daily_yield_with_cycles(
    '2025-10-15'::DATE,
    1.6,
    30.0,
    true,
    false
);

-- 結果を確認
SELECT
    user_id,
    total_nft_count,
    available_usdt,
    cum_usdt
FROM affiliate_cycle
WHERE user_id = 'YOUR_TEST_USER_ID';
```

## 影響範囲

- ✅ **個人利益計算**: 正確になる
- ✅ **紹介報酬計算**: 影響なし（別のロジック）
- ✅ **自動NFT付与**: 影響なし（STEP 3 は変更なし）
- ✅ **既存データ**: 影響なし（関数の動作のみ変更）

## 重要な注意

この修正により、**自動購入されたNFTは翌日から日利計算される**という正しい挙動になります。

例:
- 10/15に自動NFT付与 → 10/15の日利なし
- 10/16から日利計算開始 → 正しい

これは意図した動作です（NFTは翌日から運用開始）。
