# テスト環境へのインポート手順（簡易版）

## エラーの原因
`production-schema-clean.sql`を一度に実行すると、関数がテーブルより先に定義されているため、`relation "admins" does not exist`エラーが発生します。

## 解決策: 3ステップでインポート

### ステップ1: テーブル定義のみインポート

1. **テストプロジェクトのSQL Editorを開く**
   - https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/sql/new

2. **`schema-tables-only.sql`の内容をコピー&ペースト**
   ```bash
   # PowerShellまたはコマンドプロンプトで実行
   cat D:\HASHPILOT\schema-tables-only.sql
   ```

3. **SQL Editorに貼り付けて「Run」をクリック**

4. **成功を確認**（エラーがないこと）

---

### ステップ2: RPC関数のインポート

**方法A: Supabase CLIを使う（推奨）**

```bash
# テスト環境にRPC関数のみインポート
npx supabase db push --db-url "postgresql://postgres:8tZ8dZUYScKR@db.objpuphnhcjxrsiydjbf.supabase.co:5432/postgres" < production-schema-clean.sql 2>&1 | grep -v "ERROR.*already exists"
```

**方法B: 手動でコピー&ペースト**

1. `production-schema-clean.sql`をテキストエディタで開く
2. `CREATE OR REPLACE FUNCTION`で始まる部分をすべてコピー
3. SQL Editorに貼り付けて実行

---

### ステップ3: RLSポリシーのインポート

1. `production-schema-clean.sql`から以下の部分をコピー：
   - `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
   - `CREATE POLICY ...`

2. SQL Editorに貼り付けて実行

---

## より簡単な方法: すべてのテーブルを先に作成してから全体を実行

### 手順

1. **まず、テーブルだけ作成**（上記ステップ1を実行）

2. **その後、全体のSQLを実行**
   - エラーが出ても、テーブルが存在するので関数は正常に作成される
   - "already exists"エラーは無視してOK

3. **SQL Editorで実行:**
   ```bash
   cat D:\HASHPILOT\production-schema-clean.sql
   ```
   全内容をコピーして、SQL Editorで実行

---

## 確認方法

インポート完了後、以下のSQLで確認：

```sql
-- テーブル数を確認
SELECT COUNT(*) as table_count
FROM pg_tables
WHERE schemaname = 'public';
-- 期待値: 39個

-- RPC関数数を確認
SELECT COUNT(*) as function_count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.prokind = 'f';
-- 期待値: 100個以上

-- RLSポリシー数を確認
SELECT COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public';
-- 期待値: 50個以上
```

---

## 次のステップ

インポート完了後:
1. テストデータ作成（通常ユーザー＋ペガサスユーザー）
2. ペガサス制限スクリプトを実行
3. 日利処理をテスト
4. 動作確認
5. 本番環境に適用

---

**現在地**: スキーマインポート中 → **次: テストデータ作成**
