# テスト環境へのスキーマインポート手順

## 準備完了
✅ 本番環境のスキーマエクスポート完了: `production-schema.sql` (353KB)

---

## 次のステップ: テスト環境にインポート

### 方法1: Supabase CLIを使う（推奨）

1. **テストプロジェクトのデータベースパスワードを取得**

   - https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/settings/database
   - 「Database password」をコピー（作成時に設定したパスワード）
   - もし忘れた場合は、「Reset Database Password」で新しいパスワードを設定

2. **スキーマをインポート**

   ```bash
   # テストプロジェクトのデータベースパスワードを[PASSWORD]に置き換えてください
   npx supabase db push --db-url "postgresql://postgres:[PASSWORD]@db.objpuphnhcjxrsiydjbf.supabase.co:5432/postgres" --file production-schema.sql
   ```

   **注意**: パスワードに特殊文字（`%`, `@`, `#`など）が含まれる場合はURLエンコードが必要です：
   - `%` → `%25`
   - `@` → `%40`
   - `#` → `%23`
   - `&` → `%26`

---

### 方法2: Supabaseダッシュボードから手動実行

1. **テストプロジェクトのSQL Editorを開く**
   - https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/sql

2. **production-schema.sqlの内容をコピー**
   ```bash
   # ファイルの内容を表示
   cat production-schema.sql
   ```

3. **SQL Editorに貼り付けて実行**
   - 大きいファイルなので、分割して実行することを推奨：
     - Step 1: テーブル定義のみ
     - Step 2: RPC関数のみ
     - Step 3: RLSポリシーのみ

---

### 方法3: Node.jsスクリプトを使う

```javascript
// import-schema.js
const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  host: 'db.objpuphnhcjxrsiydjbf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: '[TEST_DB_PASSWORD]',
  ssl: { rejectUnauthorized: false }
});

async function importSchema() {
  await client.connect();
  const sql = fs.readFileSync('production-schema.sql', 'utf8');

  // Docker警告を除去
  const cleanSql = sql.split('\n')
    .filter(line => !line.startsWith('WARN:') && !line.includes('Pulling'))
    .join('\n');

  await client.query(cleanSql);
  console.log('✅ インポート完了！');
  await client.end();
}

importSchema();
```

実行:
```bash
node import-schema.js
```

---

## 次のステップ（インポート後）

1. テストデータ作成（通常ユーザー + ペガサスユーザー）
2. ペガサス制限スクリプトを実行
3. 日利処理をテスト実行
4. 結果確認

---

## トラブルシューティング

### エラー: "relation already exists"
- テーブルがすでに存在する場合は、先に削除してください：
  ```sql
  DROP SCHEMA public CASCADE;
  CREATE SCHEMA public;
  GRANT ALL ON SCHEMA public TO postgres;
  GRANT ALL ON SCHEMA public TO public;
  ```

### エラー: "function already exists"
- `CREATE OR REPLACE FUNCTION` を使っているので、通常は問題なし
- もしエラーが出たら、関数を手動で削除してから再実行

---

**現在地**: スキーマエクスポート完了 → **次: スキーマインポート**
