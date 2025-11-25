# テスト環境へのデータインポート手順

## 問題
- ファイルが大きすぎてSQL Editorで実行できない (2.2MB)
- Supabase CLIはネットワークエラーで接続できない

## 解決策: `psql`を使って直接インポート

### 方法1: PostgreSQL公式ツールを使う（推奨）

1. **PostgreSQL Portable版をダウンロード**
   - https://get.enterprisedb.com/postgresql/postgresql-17.0-1-windows-x64-binaries.zip
   - または、すでにPostgreSQLがインストールされている場合はスキップ

2. **解凍して`bin`フォルダに移動**
   ```cmd
   cd C:\path\to\postgresql\bin
   ```

3. **psqlコマンドでインポート**
   ```cmd
   psql -h db.objpuphnhcjxrsiydjbf.supabase.co -U postgres -d postgres -f D:\HASHPILOT\production-data-clean.sql
   ```

4. **パスワード入力**
   ```
   Password: 8tZ8dZUYScKR
   ```

---

### 方法2: DBeaver / pgAdminを使う（GUI）

1. **DBeaver（無料）をダウンロード**
   - https://dbeaver.io/download/

2. **新しい接続を作成**
   - Host: `db.objpuphnhcjxrsiydjbf.supabase.co`
   - Port: `5432`
   - Database: `postgres`
   - Username: `postgres`
   - Password: `8tZ8dZUYScKR`
   - SSL: Required

3. **SQLスクリプトを実行**
   - File > Open SQL Script
   - `D:\HASHPILOT\production-data-clean.sql`を選択
   - Execute (F5)

---

### 方法3: データを分割して手動実行

ファイルを小さなチャンクに分割して、SQL Editorで複数回実行：

```bash
# 管理者データのみ（11行）
cat D:\HASHPILOT\data-part1-admins.sql
```

テストプロジェクトのSQL Editorで実行:
- https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/sql/new

```bash
# ユーザーデータ（528行 - まだ大きいかも）
cat D:\HASHPILOT\data-part2-users.sql
```

ユーザーデータも大きい場合は、さらに分割：

```bash
# 最初の100ユーザー
head -n 150 data-part2-users.sql > users-part1.sql

# 次の100ユーザー
head -n 300 data-part2-users.sql | tail -n 150 > users-part2.sql

# 残り
tail -n +301 data-part2-users.sql > users-part3.sql
```

---

### 方法4: Supabase Studioから直接接続（最も簡単）

1. **Supabase Studioで接続文字列を取得**
   - https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/settings/database
   - 「Connection string」をコピー

2. **PowerShellで実行**（PostgreSQLがインストールされている場合）
   ```powershell
   $env:PGPASSWORD="8tZ8dZUYScKR"
   psql "postgresql://postgres@db.objpuphnhcjxrsiydjbf.supabase.co:5432/postgres" -f "D:\HASHPILOT\production-data-clean.sql"
   ```

---

## 最も簡単な方法（推奨）

**DBeaver（無料のGUIツール）を使う**

1. https://dbeaver.io/download/ からダウンロード
2. インストール
3. 新しい接続 > PostgreSQL
4. 接続情報を入力
5. SQLスクリプトを開いて実行

**所要時間**: 約5分

---

## トラブルシューティング

### エラー: "connection refused"
- ファイアウォールを確認
- SupabaseのIPホワイトリスト設定を確認（通常は不要）

### エラー: "permission denied"
- パスワードが正しいか確認
- データベース名が`postgres`であることを確認

### エラー: "duplicate key value"
- データがすでに存在する場合
- `TRUNCATE TABLE users, admins, ...` で既存データを削除してから再実行

---

**次のステップ**: データインポート完了後、ペガサス制限スクリプトを実行
