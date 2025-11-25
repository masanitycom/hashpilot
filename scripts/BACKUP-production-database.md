# 本番環境データベースのバックアップ手順

## 🎯 バックアップの目的

緊急修正を行う前に、必ず本番環境のデータベース全体のバックアップを取ります。

---

## 方法1: Supabaseダッシュボードからバックアップ（推奨）

### STEP 1: Supabaseダッシュボードにアクセス

1. https://supabase.com にアクセス
2. 本番環境のプロジェクト（HASH PILOT）を選択
3. 左メニューから「Database」→「Backups」をクリック

### STEP 2: バックアップを確認

- Supabaseは自動的に毎日バックアップを作成しています
- 「Point in Time Recovery」セクションで最新のバックアップ時刻を確認
- 必要に応じて「Download Backup」でバックアップをダウンロード

### STEP 3: 手動バックアップの作成（オプション）

Supabaseの無料プランでは手動バックアップ機能が制限されている場合があります。
その場合は、方法2のpg_dumpを使用してください。

---

## 方法2: pg_dumpコマンドでバックアップ（確実）

### 前提条件

- PostgreSQL クライアントツールがインストールされている
- Supabaseの接続情報（接続文字列）が必要

### STEP 1: Supabase接続情報を取得

1. Supabaseダッシュボードで「Settings」→「Database」をクリック
2. 「Connection string」セクションで「URI」をコピー
3. パスワード部分を実際のパスワードに置き換える

例:
```
postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

### STEP 2: バックアップスクリプトを実行

以下のスクリプトを使用してバックアップを作成します。

```bash
# バックアップディレクトリを作成
mkdir -p backups

# 現在の日時を取得
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

# pg_dumpでバックアップを作成
pg_dump "postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres" \
  --file="backups/production_backup_${BACKUP_DATE}.sql" \
  --verbose \
  --no-owner \
  --no-acl

# バックアップファイルを圧縮
gzip "backups/production_backup_${BACKUP_DATE}.sql"

echo "✅ バックアップ完了: backups/production_backup_${BACKUP_DATE}.sql.gz"
```

### STEP 3: バックアップの確認

```bash
# バックアップファイルのサイズを確認
ls -lh backups/

# バックアップファイルの内容を確認（最初の20行）
zcat backups/production_backup_*.sql.gz | head -20
```

---

## 方法3: 重要なテーブルのみバックアップ（軽量版）

今回の修正で影響を受けるテーブルのみをバックアップします。

### STEP 1: バックアップスクリプトを実行

```bash
# バックアップディレクトリを作成
mkdir -p backups/tables

# 現在の日時を取得
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

# 影響を受けるテーブルをバックアップ
TABLES=(
  "users"
  "nft_daily_profit"
  "user_referral_profit"
  "affiliate_cycle"
  "nft_master"
  "purchases"
)

for table in "${TABLES[@]}"; do
  echo "バックアップ中: $table"
  pg_dump "postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres" \
    --table="public.$table" \
    --file="backups/tables/${table}_${BACKUP_DATE}.sql" \
    --data-only \
    --column-inserts
done

# すべてのバックアップを1つのファイルに圧縮
tar -czf "backups/critical_tables_${BACKUP_DATE}.tar.gz" backups/tables/

echo "✅ テーブルバックアップ完了: backups/critical_tables_${BACKUP_DATE}.tar.gz"
```

---

## 方法4: SQL経由でバックアップ（最も簡単）

SupabaseのSQL Editorで直接実行できるバックアップスクリプトです。

### STEP 1: バックアップ用テーブルを作成

```sql
-- バックアップ用のスキーマを作成
CREATE SCHEMA IF NOT EXISTS backup_20251115;

-- usersテーブルのバックアップ
CREATE TABLE backup_20251115.users AS
SELECT * FROM public.users;

-- nft_daily_profitテーブルのバックアップ
CREATE TABLE backup_20251115.nft_daily_profit AS
SELECT * FROM public.nft_daily_profit;

-- user_referral_profitテーブルのバックアップ
CREATE TABLE backup_20251115.user_referral_profit AS
SELECT * FROM public.user_referral_profit;

-- affiliate_cycleテーブルのバックアップ
CREATE TABLE backup_20251115.affiliate_cycle AS
SELECT * FROM public.affiliate_cycle;

-- nft_masterテーブルのバックアップ
CREATE TABLE backup_20251115.nft_master AS
SELECT * FROM public.nft_master;

-- purchasesテーブルのバックアップ
CREATE TABLE backup_20251115.purchases AS
SELECT * FROM public.purchases;

-- バックアップの確認
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = schemaname AND table_name = tablename) as exists
FROM pg_tables
WHERE schemaname = 'backup_20251115'
ORDER BY tablename;
```

### STEP 2: バックアップの確認

```sql
-- 各テーブルのレコード数を確認
SELECT 'users' as table_name, COUNT(*) as record_count FROM backup_20251115.users
UNION ALL
SELECT 'nft_daily_profit', COUNT(*) FROM backup_20251115.nft_daily_profit
UNION ALL
SELECT 'user_referral_profit', COUNT(*) FROM backup_20251115.user_referral_profit
UNION ALL
SELECT 'affiliate_cycle', COUNT(*) FROM backup_20251115.affiliate_cycle
UNION ALL
SELECT 'nft_master', COUNT(*) FROM backup_20251115.nft_master
UNION ALL
SELECT 'purchases', COUNT(*) FROM backup_20251115.purchases;
```

### 復元方法（必要な場合）

```sql
-- 例: usersテーブルの復元
BEGIN;

-- 現在のデータを削除（慎重に！）
DELETE FROM public.users;

-- バックアップから復元
INSERT INTO public.users
SELECT * FROM backup_20251115.users;

-- 確認してからコミット
-- COMMIT;
ROLLBACK; -- 問題があればロールバック
```

---

## 🎯 推奨手順

**最も簡単で確実な方法:**

1. **方法4（SQL経由）でバックアップを作成** ← まずこれを実行
2. **方法2（pg_dump）で完全バックアップを作成** ← 時間があればこれも実行

**理由:**
- 方法4は即座に実行でき、復元も簡単
- 方法2は完全なバックアップで、万が一の場合も安心
- 両方実行すれば二重のセーフティネット

---

## ✅ バックアップ完了の確認

以下をすべて確認してから、修正作業に進んでください：

- [ ] バックアップが作成された（方法4のSQLスクリプトが成功）
- [ ] バックアップのレコード数が正しい（元のテーブルと一致）
- [ ] backup_20251115スキーマが存在する
- [ ] すべてのテーブルがバックアップされた
- [ ] バックアップの確認クエリが正常に動作する

---

## 📝 バックアップ情報の記録

バックアップを作成したら、以下の情報を記録してください：

```
バックアップ日時: 2025-11-15 [実行時刻]
バックアップ方法: 方法4（SQL経由）
スキーマ名: backup_20251115
テーブル数: 6
総レコード数: [確認クエリの結果]
```

---

## 🆘 トラブルシューティング

### バックアップの作成に失敗する場合

1. Supabaseの接続情報が正しいか確認
2. パスワードが正しいか確認
3. PostgreSQLクライアントがインストールされているか確認
4. ネットワーク接続を確認

### バックアップのサイズが異常に小さい場合

- データが正しくバックアップされていない可能性
- 確認クエリでレコード数を確認
- 元のテーブルと比較

---

最終更新: 2025年11月15日
