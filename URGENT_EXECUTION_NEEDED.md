# 🚨 緊急実行が必要

## 重大な問題

**user_daily_profitテーブルが完全に空**
- 日利処理が一度も実行されていない
- ダッシュボードで406エラー発生
- 全ユーザーの利益データが存在しない

## 緊急対応

### 1. 原因調査と手動データ作成
```sql
-- Supabase SQL Editorで実行
\i scripts/check-daily-profit-execution.sql
```

### 2. フロントエンド用RLSポリシー修正
```sql
-- user_daily_profitテーブルのRLS修正
DROP POLICY IF EXISTS "anon_users_read_daily_profit" ON user_daily_profit;

CREATE POLICY "allow_frontend_access" ON user_daily_profit
    FOR SELECT
    TO public
    USING (true);
```

### 3. 確認
- ダッシュボードで406エラーが解消される
- 利益データが正しく表示される
- 紹介報酬が正しく計算される

## 影響範囲
- **全ユーザー**: 利益データが表示されない
- **ダッシュボード**: 機能停止
- **紹介報酬**: 計算不可能

**即座に対応が必要です！**