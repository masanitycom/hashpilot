# 休眠ユーザーシステム セットアップガイド

## 📋 概要

全NFTを売却したユーザーを「休眠」扱いにし、その期間の紹介報酬を会社アカウント（7A9637）が受け取るシステムです。

## 🎯 仕様

### 休眠ユーザーとは
- **定義**: 全NFTを売却し、現在NFTを保有していないユーザー
- **フラグ**: `users.is_active_investor = FALSE`

### 報酬の流れ

#### 通常時（アクティブユーザー）
```
子ユーザーA の利益 → Level1（親B）へ10%報酬
                  → Level2（祖父C）へ5%報酬
                  → Level3（曾祖父D）へ3%報酬
```

#### 休眠時（Bが休眠中）
```
子ユーザーA の利益 → Level1（7A9637）へ10%報酬 🏢
                  → Level2（祖父C）へ5%報酬
                  → Level3（曾祖父D）へ3%報酬

※ 会社ボーナステーブルに記録:
  - 休眠ユーザー: B
  - 報酬発生元: A
  - 金額: 10%
```

### 自動復帰
- ユーザーBが再度NFTを購入 → `is_active_investor = TRUE` に自動更新
- 次回からBが通常通り報酬を受け取る

## 🚀 セットアップ手順

### ステップ1: データベーススキーマ作成

⚠️ **重要: 以下の順序で実行してください**

#### 1-1. user_referral_profit テーブル作成（必須・最初に実行）
```sql
-- scripts/create-user-referral-profit-table.sql の内容を実行
```

**作成されるもの:**
- `user_referral_profit` テーブル
- `user_referral_profit_summary` ビュー
- `user_total_referral_profit` ビュー

#### 1-2. 休眠ユーザーフラグと会社ボーナステーブル
```sql
-- scripts/implement-dormant-user-company-bonus.sql の内容を実行
```

**作成されるもの:**
- `users.is_active_investor` カラム
- `company_bonus_from_dormant` テーブル
- `company_bonus_summary` ビュー
- `dormant_users_list` ビュー
- 自動更新トリガー

#### 1-3. 紹介報酬計算ロジック更新
```sql
-- scripts/update-referral-calculation-for-dormant.sql の内容を実行
```

**作成されるもの:**
- `calculate_referral_rewards_with_dormant()` 関数
- `get_company_bonus_report()` 関数
- `company_account_referral_summary` ビュー

### ステップ2: 動作確認

#### テスト実行（日次報酬計算）
```sql
-- 2025年10月7日の紹介報酬を計算（テストモード）
SELECT * FROM calculate_referral_rewards_with_dormant('2025-10-07', TRUE);
```

**期待される結果:**
```
status         | total_users | total_rewards | company_bonus_from_dormant | message
---------------|-------------|---------------|----------------------------|------------------
TEST_SUCCESS   | 50          | 125.50        | 15.30                      | テスト完了: 50名処理...
```

#### 会社ボーナスレポート確認
```sql
-- 過去30日の会社ボーナスを確認
SELECT * FROM get_company_bonus_report();
```

**期待される結果:**
```
report_date | total_bonus | bonus_count | dormant_users_count | level1_bonus | level2_bonus | level3_bonus
------------|-------------|-------------|---------------------|--------------|--------------|-------------
2025-10-07  | 15.30       | 8           | 2                   | 10.20        | 3.50         | 1.60
2025-10-06  | 12.50       | 6           | 2                   | 8.00         | 3.00         | 1.50
```

#### 7A9637アカウントの報酬サマリー
```sql
-- 会社アカウントの紹介報酬詳細
SELECT * FROM company_account_referral_summary LIMIT 10;
```

**期待される結果:**
```
date       | total_referral_profit | level1_profit | level2_profit | level3_profit | bonus_from_dormant | normal_referral_profit
-----------|----------------------|---------------|---------------|---------------|--------------------|-----------------------
2025-10-07 | 215.30               | 150.20        | 45.50         | 19.60         | 15.30              | 200.00
```

## 📊 作成されるテーブル・ビュー

### company_bonus_from_dormant テーブル
| カラム | 型 | 説明 |
|--------|-----|------|
| id | UUID | レコードID |
| date | DATE | 日付 |
| dormant_user_id | TEXT | 休眠中のユーザーID |
| dormant_user_email | TEXT | 休眠ユーザーのメール |
| child_user_id | TEXT | 報酬発生元のユーザーID |
| referral_level | INTEGER | レベル (1, 2, 3) |
| original_amount | DECIMAL | 本来受け取るはずだった金額 |
| company_user_id | TEXT | 会社アカウント（7A9637） |

### company_bonus_summary ビュー
日次の会社ボーナスサマリー

### dormant_users_list ビュー
休眠ユーザー一覧と会社への貢献度

### company_account_referral_summary ビュー
7A9637の紹介報酬詳細（通常報酬と休眠ボーナスを分離）

## 🔧 提供される関数

### calculate_referral_rewards_with_dormant(p_date, p_is_test_mode)
紹介報酬を計算（休眠ユーザー対応）

**パラメータ:**
- `p_date`: 計算対象日
- `p_is_test_mode`: TRUE=テスト、FALSE=本番

**戻り値:**
- `status`: 実行結果
- `total_users`: 処理ユーザー数
- `total_rewards`: 総報酬額
- `company_bonus_from_dormant`: 会社ボーナス額
- `message`: メッセージ

### get_company_bonus_report(p_start_date, p_end_date)
会社ボーナスレポートを取得

**パラメータ:**
- `p_start_date`: 開始日（デフォルト: 30日前）
- `p_end_date`: 終了日（デフォルト: 今日）

## 🔄 自動処理

### NFT購入時
```
トリガー: nft_master に新規レコード挿入
↓
is_active_investor = TRUE に自動更新
```

### NFT買い取り承認時
```
トリガー: nft_master の buyback_date 更新
↓
保有NFT数をチェック
↓
0枚なら is_active_investor = FALSE に自動更新
1枚以上なら is_active_investor = TRUE
```

## 📈 管理画面での表示イメージ

### 7A9637 ダッシュボード
```
会社ボーナス（休眠ユーザーから）:
┌──────────────────────────────────────────┐
│ 日付       │ 金額    │ 休眠ユーザー数 │
├──────────────────────────────────────────┤
│ 2025/10/07 │ $15.30  │ 2名 (B, E)     │
│ 2025/10/06 │ $12.50  │ 2名 (B, E)     │
│ 2025/10/05 │ $18.20  │ 3名 (B, E, F)  │
└──────────────────────────────────────────┘

詳細:
- Bの休眠により: $8.50 (Level1: $5.00, Level2: $2.50, Level3: $1.00)
- Eの休眠により: $6.80 (Level1: $4.00, Level2: $2.00, Level3: $0.80)
```

## ⚠️ 重要な注意事項

1. **報酬計算の順序**
   - 日次利益計算を先に実行
   - その後、紹介報酬計算を実行

2. **is_active_investor の管理**
   - 自動更新されるため、手動変更は不要
   - トリガーで管理されている

3. **データの整合性**
   - 買い取り申請承認時に自動更新
   - NFT購入時に自動更新

## 🔍 確認クエリ

### 休眠ユーザー一覧
```sql
SELECT * FROM dormant_users_list;
```

### 特定ユーザーの状態確認
```sql
SELECT
    user_id,
    email,
    is_active_investor,
    (SELECT total_nft_count FROM affiliate_cycle WHERE user_id = users.user_id) as nft_count
FROM users
WHERE user_id = 'XXXXX';
```

### 会社ボーナスの詳細
```sql
SELECT
    date,
    dormant_user_id,
    dormant_user_email,
    child_user_id,
    referral_level,
    original_amount
FROM company_bonus_from_dormant
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC, original_amount DESC;
```

## 📞 サポート

問題が発生した場合は、以下の情報と共に報告してください：
1. 実行したSQL
2. エラーメッセージ
3. 確認クエリの結果

---

最終更新: 2025年10月7日
