# NFT利益追跡システム セットアップガイド

## 📋 概要
NFTごとの利益を追跡し、正確な買い取り金額を計算するシステムをセットアップします。

## 🚀 実行手順

### ステップ1: Supabaseダッシュボードにアクセス

1. https://app.supabase.com にアクセス
2. プロジェクトを選択
3. 左メニューから **SQL Editor** をクリック

### ステップ2: テーブルとビュー・関数を作成

1. **New query** をクリック
2. 以下のファイルの内容を全てコピー:
   ```
   scripts/create-nft-profit-tracking.sql
   ```
3. SQL Editorにペースト
4. **Run** をクリック

**期待される結果:**
```
✅ NFT利益追跡システムのテーブルと関数を作成しました
📋 作成されたオブジェクト:
   - nft_master テーブル
   - nft_daily_profit テーブル
   - nft_referral_profit テーブル
   - nft_total_profit ビュー
   - calculate_nft_buyback_amount() 関数
   - calculate_user_all_nft_buyback() 関数
```

### ステップ3: 既存NFTデータを移行

1. **New query** をクリック
2. 以下のファイルの内容を全てコピー:
   ```
   scripts/migrate-existing-nfts-to-master.sql
   ```
3. SQL Editorにペースト
4. **Run** をクリック

**期待される結果:**
```
🔄 手動購入NFTを移行中...
  ✅ user001: 3 個の手動NFTを移行
  ✅ user002: 2 個の手動NFTを移行
  ...
✅ 手動購入NFTの移行完了

🔄 自動購入NFTを移行中...
  ✅ user001: 1 個の自動NFTを移行 (日付: 2025-07-15)
  ...
✅ 自動購入NFTの移行完了

📊 NFT移行結果サマリー
[ユーザーごとの確認テーブルが表示される]
```

### ステップ4: 移行結果の確認

最後のクエリ結果を確認し、すべてのユーザーが「✅ 一致」となっていることを確認してください。

もし「❌ 不一致」があれば、そのユーザーの詳細を確認する必要があります。

## 📊 作成されるテーブル構造

### nft_master
| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | NFT ID (主キー) |
| user_id | TEXT | ユーザーID |
| nft_sequence | INTEGER | NFT番号 (1, 2, 3...) |
| nft_type | TEXT | 'manual' または 'auto' |
| nft_value | DECIMAL | NFT価値 (1100) |
| acquired_date | DATE | 取得日 |
| buyback_date | DATE | 買い取り日 (NULL=保有中) |

### nft_daily_profit
| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | レコードID |
| nft_id | UUID | NFT ID (外部キー) |
| user_id | TEXT | ユーザーID |
| date | DATE | 日付 |
| daily_profit | DECIMAL | その日の利益 |
| yield_rate | DECIMAL | 日利率 |
| user_rate | DECIMAL | ユーザー受取率 |
| base_amount | DECIMAL | 運用額 (1100) |
| phase | TEXT | USDT or HOLD |

### nft_referral_profit
| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | レコードID |
| nft_id | UUID | NFT ID (外部キー) |
| user_id | TEXT | ユーザーID |
| date | DATE | 日付 |
| referral_profit | DECIMAL | その日の紹介報酬 |
| level1_profit | DECIMAL | Level1報酬 |
| level2_profit | DECIMAL | Level2報酬 |
| level3_profit | DECIMAL | Level3報酬 |

## 🔧 提供される関数

### calculate_nft_buyback_amount(nft_id UUID)
NFT1個の買い取り金額を計算

**計算式:**
- 手動NFT: `1000 - (個人収益累計 ÷ 2)`
- 自動NFT: `500 - (個人収益累計 ÷ 2)`

**使用例:**
```sql
SELECT calculate_nft_buyback_amount('nft_id_here');
```

### calculate_user_all_nft_buyback(user_id TEXT, nft_type TEXT)
ユーザーの全NFTまたは指定タイプのNFT買い取り金額を計算

**使用例:**
```sql
-- 全NFT
SELECT * FROM calculate_user_all_nft_buyback('user001', NULL);

-- 手動NFTのみ
SELECT * FROM calculate_user_all_nft_buyback('user001', 'manual');

-- 自動NFTのみ
SELECT * FROM calculate_user_all_nft_buyback('user001', 'auto');
```

## ⚠️ 重要な注意事項

1. **買い取り計算**: 個人収益のみを使用（紹介報酬は含めない）
2. **データの整合性**: 移行後は `affiliate_cycle` の NFT数と一致することを確認
3. **外部キー**: NFT削除時に関連する利益データも自動削除 (CASCADE)

## 🔍 確認クエリ

### 特定ユーザーのNFT一覧
```sql
SELECT * FROM nft_total_profit
WHERE user_id = 'user001'
ORDER BY nft_sequence;
```

### 買い取り可能なNFT一覧（保有中）
```sql
SELECT
    user_id,
    nft_sequence,
    nft_type,
    total_personal_profit,
    calculate_nft_buyback_amount(nft_id) as buyback_amount
FROM nft_total_profit
WHERE buyback_date IS NULL
ORDER BY user_id, nft_sequence;
```

## 📞 サポート

問題が発生した場合は、以下の情報と共に報告してください:
1. 実行したSQL
2. エラーメッセージ
3. 移行結果の確認クエリの結果

---

最終更新: 2025年10月6日
