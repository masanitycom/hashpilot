# 月末自動出金処理のセットアップガイド

## 概要
月末自動出金処理は、毎月最終日の23:59（日本時間）に実行され、100 USDT以上の残高を持つユーザーの出金申請を自動作成します。

## セットアップ方法

### 1. SQLファンクションの作成
```bash
# Supabase SQL Editorで実行
scripts/create-monthly-withdrawal-function.sql
```

### 2. Edge Functionのデプロイ
```bash
# ローカルでテスト
supabase functions serve monthly-withdrawal

# 本番環境にデプロイ
supabase functions deploy monthly-withdrawal
```

### 3. スケジュール設定（3つの選択肢）

#### オプション1: Supabase Dashboard（推奨）
1. Supabase Dashboardにログイン
2. Edge Functions → monthly-withdrawal を選択
3. "Schedule" タブを開く
4. 以下の設定を追加：
   - Schedule: `59 23 * * *` （毎日23:59）
   - Timezone: `Asia/Tokyo`

#### オプション2: Vercel Cron
```javascript
// vercel.json
{
  "crons": [{
    "path": "/api/trigger-monthly-withdrawal",
    "schedule": "59 23 * * *"
  }]
}
```

#### オプション3: GitHub Actions
```yaml
name: Monthly Withdrawal
on:
  schedule:
    - cron: '59 14 * * *'  # UTC 14:59 = JST 23:59
jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger withdrawal
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json" \
            https://[YOUR_PROJECT_REF].supabase.co/functions/v1/monthly-withdrawal
```

## テスト方法

### 1. 対象ユーザーの確認
```sql
-- どのユーザーが月末処理対象になるか確認
SELECT * FROM test_monthly_auto_withdrawal();
```

### 2. 月末チェック
```sql
-- 今日が月末かどうか確認（日本時間）
SELECT is_month_end_jst();
```

### 3. 手動実行（管理者のみ）
```bash
# curlで実行
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  https://[YOUR_PROJECT_REF].supabase.co/functions/v1/monthly-withdrawal
```

## 処理内容

1. **日本時間で月末判定**
   - 日本時間（Asia/Tokyo）で現在日付を取得
   - 月末日でない場合は処理をスキップ

2. **対象ユーザーの抽出**
   - available_usdt >= 100 のユーザー
   - 当月の自動出金申請が未作成のユーザー

3. **出金申請の作成**
   - withdrawalsテーブルに新規レコード作成
   - status: 'pending'
   - withdrawal_type: 'monthly_auto'

4. **残高のリセット**
   - available_usdtを0にリセット
   - last_updatedを更新

5. **ログ記録**
   - 処理件数と総額を記録

## 注意事項

- 最低出金額: 100 USDT
- 処理は月末のみ実行（手動実行時も月末チェックあり）
- 重複実行防止のため、同月の申請は作成されない
- 管理者の承認が必要（自動承認ではない）