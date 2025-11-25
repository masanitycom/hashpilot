# 最も簡単なスキーマエクスポート方法

## 方法1: Supabaseダッシュボードから直接ダウンロード

### 手順

1. **本番Supabaseにアクセス**
   - https://app.supabase.com/project/soghqozaxfswtxxbgeer

2. **Database > Migrations に移動**
   - 左メニュー > Database > Migrations

3. **"Create a new migration" をクリック**

4. **"From dashboard" オプションを選択**

5. **スキーマ全体をマイグレーションファイルとしてダウンロード**

これで、すべてのテーブル、関数、RLSポリシーが1つのSQLファイルになります。

---

## 方法2: pg_dump を使う（最も確実）

### 前提条件
- PostgreSQLクライアントがインストールされている
- または、オンラインツールを使用

### オンラインツール使用
1. https://www.pgadmin.org/download/ からpgAdmin（GUIツール）をダウンロード
2. 本番データベースに接続:
   - Host: db.soghqozaxfswtxxbgeer.supabase.co
   - Port: 5432
   - Database: postgres
   - Username: postgres
   - Password: y1TuMih%%wFrMc3H

3. 右クリック > Backup
4. Format: Plain
5. 「Schema only」を選択（データは含めない）

---

## 方法3: Supabase CLIを使う（Dockerなし）

実は、Supabase CLIの `db dump` はリモートからも実行できます：

```bash
# リモートダンプ（Dockerなしでも動作する場合がある）
npx supabase db dump --db-url "postgresql://postgres:y1TuMih%%wFrMc3H@db.soghqozaxfswtxxbgeer.supabase.co:5432/postgres" --schema public
```

出力をファイルに保存:
```bash
npx supabase db dump --db-url "postgresql://postgres:y1TuMih%%wFrMc3H@db.soghqozaxfswtxxbgeer.supabase.co:5432/postgres" --schema public > schema.sql
```

---

## 方法4: Node.jsスクリプトでエクスポート

`pg` パッケージを使ってNode.jsスクリプトを書く：

```javascript
const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  host: 'db.soghqozaxfswtxxbgeer.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'y1TuMih%%wFrMc3H',
  ssl: { rejectUnauthorized: false }
});

async function exportSchema() {
  await client.connect();

  // テーブル一覧取得
  const tables = await client.query(`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  `);

  // RPC関数取得
  const functions = await client.query(`
    SELECT pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.prokind = 'f'
  `);

  // ... 他のスキーマ要素も同様に取得

  await client.end();
}

exportSchema();
```

---

## 推奨: 方法1（Supabaseダッシュボード）

最も簡単で確実です。

1. Dashboard > Migrations
2. Create migration from dashboard
3. ダウンロード
4. テスト環境で実行

これで完全なスキーマがエクスポートされます。
