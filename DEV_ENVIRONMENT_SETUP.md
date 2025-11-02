# 開発環境セットアップガイド（完全版）

## 📋 目次
1. [環境の全体像](#環境の全体像)
2. [テスト用Supabaseプロジェクトの作成](#テスト用supabaseプロジェクトの作成)
3. [データベーススキーマのコピー](#データベーススキーマのコピー)
4. [テストデータの投入](#テストデータの投入)
5. [環境変数の設定](#環境変数の設定)
6. [Vercel Staging環境の設定](#vercel-staging環境の設定)
7. [ノートPCでの作業手順](#ノートpcでの作業手順)
8. [トラブルシューティング](#トラブルシューティング)

---

## 環境の全体像

```
┌─────────────────────────────────────────────────────────────┐
│ 開発環境 (localhost:3000)                                    │
│ ├── Next.jsアプリ: ローカルで実行                             │
│ └── データベース: テスト用Supabase ← 本番とは完全分離         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Staging環境 (hashpilot-staging.vercel.app)                  │
│ ├── Next.jsアプリ: Vercel (stagingブランチ)                  │
│ └── データベース: テスト用Supabase ← 本番とは完全分離         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 本番環境 (hashpilot.net)                                     │
│ ├── Next.jsアプリ: Vercel (mainブランチ)                     │
│ └── データベース: 本番Supabase ← 本番データ                   │
└─────────────────────────────────────────────────────────────┘
```

---

## テスト用Supabaseプロジェクトの作成

### 1. Supabaseダッシュボードにアクセス
https://supabase.com/dashboard

### 2. 新しいプロジェクトを作成
1. **New Project** をクリック
2. 以下の情報を入力:
   - **Name**: `hashpilot-test` (テスト用とわかる名前)
   - **Database Password**: 強力なパスワード（メモしておく）
   - **Region**: `Northeast Asia (Tokyo)` (本番と同じ)
   - **Pricing Plan**: `Free` (開発用は無料プランでOK)
3. **Create new project** をクリック

### 3. プロジェクトURLとAPIキーを確認
プロジェクト作成後、以下の情報をメモ:

```
Settings → API

- Project URL: https://xxxxxx.supabase.co
- anon public key: eyJhbGc...
- service_role key: eyJhbGc... (⚠️ 絶対に公開しない)
```

---

## データベーススキーマのコピー

### 方法1: SQLスクリプトを使用（推奨）

#### 1-1. 本番データベースのスキーマをエクスポート

本番Supabaseダッシュボード:
1. **SQL Editor** を開く
2. 以下のSQLを実行してスキーマ情報を取得:

```sql
-- テーブル一覧の確認
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- RPC関数一覧の確認
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION';
```

#### 1-2. スキーマファイルの準備

プロジェクトルートに `scripts/init-test-database.sql` が既にあります。
このファイルを使用してテスト用データベースを初期化します。

```bash
# ファイルの確認
ls scripts/init-test-database.sql
```

#### 1-3. テスト用Supabaseでスキーマを実行

テスト用Supabaseダッシュボード:
1. **SQL Editor** を開く
2. `scripts/init-test-database.sql` の内容をコピー＆ペースト
3. **Run** をクリック

### 方法2: Supabase CLIを使用（上級者向け）

```bash
# 本番データベースからスキーマをダンプ
npx supabase db dump --db-url "postgresql://postgres:[PASSWORD]@db.soghqozaxfswtxxbgeer.supabase.co:5432/postgres" > schema.sql

# テスト用データベースにインポート
npx supabase db push --db-url "postgresql://postgres:[PASSWORD]@db.xxxxxx.supabase.co:5432/postgres" < schema.sql
```

---

## テストデータの投入

### 1. ダミーユーザーの作成

テスト用Supabaseダッシュボード → SQL Editor:

```sql
-- テスト用管理者ユーザー
INSERT INTO users (
  user_id, email, full_name, password_hash,
  is_admin, operation_start_date, has_approved_nft,
  total_purchases, nft_receive_address
) VALUES (
  'test-admin-001',
  'admin@test.hashpilot.local',
  'テスト管理者',
  '$2a$10$dummyhashfortest',
  true,
  '2025-11-01',
  true,
  10000,
  '0xTESTADMINADDRESS123'
);

-- テスト用一般ユーザー1（運用中）
INSERT INTO users (
  user_id, email, full_name, password_hash,
  is_admin, operation_start_date, has_approved_nft,
  total_purchases, nft_receive_address, referrer_user_id
) VALUES (
  'test-user-001',
  'user1@test.hashpilot.local',
  'テストユーザー1',
  '$2a$10$dummyhashfortest',
  false,
  '2025-11-01',
  true,
  1100,
  '0xTESTUSER1ADDRESS123',
  NULL
);

-- テスト用一般ユーザー2（運用待機中）
INSERT INTO users (
  user_id, email, full_name, password_hash,
  is_admin, operation_start_date, has_approved_nft,
  total_purchases, nft_receive_address, referrer_user_id
) VALUES (
  'test-user-002',
  'user2@test.hashpilot.local',
  'テストユーザー2',
  '$2a$10$dummyhashfortest',
  false,
  '2025-11-15',
  true,
  1100,
  '0xTESTUSER2ADDRESS123',
  'test-user-001'
);

-- テスト用一般ユーザー3（未承認）
INSERT INTO users (
  user_id, email, full_name, password_hash,
  is_admin, operation_start_date, has_approved_nft,
  total_purchases, nft_receive_address, referrer_user_id
) VALUES (
  'test-user-003',
  'user3@test.hashpilot.local',
  'テストユーザー3',
  '$2a$10$dummyhashfortest',
  false,
  NULL,
  false,
  0,
  '0xTESTUSER3ADDRESS123',
  'test-user-001'
);
```

### 2. affiliate_cycleの初期化

```sql
-- 運用中ユーザーのサイクル初期化
INSERT INTO affiliate_cycle (user_id, cycle_number, cum_usdt, available_usdt, phase)
VALUES
  ('test-user-001', 1, 0, 0, 'USDT'),
  ('test-user-002', 1, 0, 0, 'USDT');
```

### 3. テスト用日利データ

```sql
-- 11/1のテスト日利
INSERT INTO daily_yields (date, yield_rate, margin_rate, user_rate)
VALUES
  ('2025-11-01', 0.016, 0.30, 0.00672);

-- 11/2のテスト日利
INSERT INTO daily_yields (date, yield_rate, margin_rate, user_rate)
VALUES
  ('2025-11-02', -0.002, 0.30, -0.00084);
```

### 4. NFTマスターデータ

```sql
-- テストユーザー1のNFT
INSERT INTO nft_master (user_id, nft_count, is_auto_purchase)
VALUES
  ('test-user-001', 1, false);
```

---

## 環境変数の設定

### 1. `.env.local` の作成（ローカル開発用）

プロジェクトルートに `.env.local` を作成:

```bash
# テスト用Supabase（開発環境用）
NEXT_PUBLIC_SUPABASE_URL=https://xxxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...

# 環境識別
NEXT_PUBLIC_ENV=development
NEXT_PUBLIC_SITE_URL=http://localhost:3000

# システム設定
NEXT_PUBLIC_SYSTEM_PREPARING=false
NEXT_PUBLIC_SHOW_TEST_NOTICE=true

# ベーシック認証（ローカルでは不要）
# BASIC_AUTH_USER=admin
# BASIC_AUTH_PASSWORD=
```

⚠️ **重要**: `.env.local` は `.gitignore` に含まれているのでGitにコミットされません

### 2. `.env.production.local` の作成（本番確認用）

本番データベースを確認したい場合のみ使用:

```bash
# 本番Supabase
NEXT_PUBLIC_SUPABASE_URL=https://soghqozaxfswtxxbgeer.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=(本番のキー)
SUPABASE_SERVICE_ROLE_KEY=(本番のキー)

# 環境識別
NEXT_PUBLIC_ENV=production
NEXT_PUBLIC_SITE_URL=http://localhost:3000

# システム設定
NEXT_PUBLIC_SYSTEM_PREPARING=false
NEXT_PUBLIC_SHOW_TEST_NOTICE=false
```

### 3. 環境の切り替え方法

```bash
# 通常はテスト環境で開発
npm run dev
# → .env.local が使用される

# 本番データを確認したい場合（読み取り専用推奨）
mv .env.local .env.local.backup
mv .env.production.local .env.local
npm run dev

# 終わったら戻す
mv .env.local .env.production.local
mv .env.local.backup .env.local
```

---

## Vercel Staging環境の設定

### 1. Vercelダッシュボードにアクセス
https://vercel.com/maxs-projects-a7b6af88/hashpilot

### 2. Environment Variables を設定

**Settings → Environment Variables**

#### Preview (stagingブランチ用) の環境変数:

| 変数名 | 値 | 環境 |
|--------|-----|------|
| `NEXT_PUBLIC_ENV` | `staging` | Preview |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://xxxxxx.supabase.co` (テスト用) | Preview |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `eyJhbGc...` (テスト用) | Preview |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGc...` (テスト用) | Preview |
| `NEXT_PUBLIC_SITE_URL` | `https://hashpilot-staging.vercel.app` | Preview |
| `BASIC_AUTH_USER` | `admin` | Preview |
| `BASIC_AUTH_PASSWORD` | `(強力なパスワード)` | Preview |
| `NEXT_PUBLIC_SYSTEM_PREPARING` | `false` | Preview |
| `NEXT_PUBLIC_SHOW_TEST_NOTICE` | `true` | Preview |

#### Production (mainブランチ用) の環境変数:

| 変数名 | 値 | 環境 |
|--------|-----|------|
| `NEXT_PUBLIC_ENV` | `production` | Production |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://soghqozaxfswtxxbgeer.supabase.co` (本番) | Production |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `(本番のキー)` | Production |
| `SUPABASE_SERVICE_ROLE_KEY` | `(本番のキー)` | Production |
| `NEXT_PUBLIC_SITE_URL` | `https://hashpilot.net` | Production |
| `NEXT_PUBLIC_SYSTEM_PREPARING` | `false` | Production |
| `NEXT_PUBLIC_SHOW_TEST_NOTICE` | `false` | Production |

### 3. 環境変数の追加方法

1. **Settings → Environment Variables**
2. **Add New** をクリック
3. **Name**: 変数名を入力
4. **Value**: 値を入力
5. **Environments**: `Preview` または `Production` を選択
   - Preview: stagingブランチ用
   - Production: mainブランチ用
6. **Save** をクリック

### 4. 再デプロイ

環境変数を変更した場合は再デプロイが必要:

1. **Deployments** タブ
2. 最新のデプロイの **...** → **Redeploy**

---

## ノートPCでの作業手順

### 初回セットアップ（ノートPCで一度だけ実行）

```bash
# 1. リポジトリをクローン
git clone https://github.com/yourusername/hashpilot.git
cd hashpilot

# 2. 依存関係をインストール
npm install

# 3. .env.local を作成（上記の「環境変数の設定」を参照）
# エディタで .env.local を作成して、テスト用Supabaseの情報を入力

# 4. 開発サーバーを起動
npm run dev

# 5. ブラウザで確認
# http://localhost:3000
```

### 日常の作業フロー

```bash
# 1. stagingブランチに切り替え
git checkout staging

# 2. 最新の変更を取得
git pull origin staging

# 3. 開発サーバーを起動
npm run dev

# 4. 機能を開発・テスト
# ブラウザで http://localhost:3000 にアクセス
# テスト用データベースなので自由に実験可能

# 5. コミット＆プッシュ
git add .
git commit -m "新機能追加"
git push origin staging

# 6. Staging環境で確認
# https://hashpilot-staging.vercel.app
# ベーシック認証: admin / (設定したパスワード)

# 7. テストOKなら本番に反映
git checkout main
git merge staging
git push origin main

# 8. 本番環境で確認
# https://hashpilot.net
```

### .env.local の管理（複数PCで作業する場合）

**⚠️ 重要**: `.env.local` はGitにコミットされないため、各PCで個別に作成が必要

#### 方法1: 手動でコピー（推奨）

デスクトップPCから `.env.local` の内容をコピーして、ノートPCで同じファイルを作成

#### 方法2: 暗号化して管理（上級者向け）

```bash
# デスクトップPCで暗号化
gpg -c .env.local
# → .env.local.gpg が作成される（これはGitにコミット可能）

# ノートPCで復号化
gpg -d .env.local.gpg > .env.local
```

#### 方法3: 環境変数管理ツールを使用

- [dotenv-vault](https://www.dotenv.org/docs/security/env-vault)
- [1Password CLI](https://developer.1password.com/docs/cli/)

---

## トラブルシューティング

### 問題1: ローカルで起動しない

**エラー**: `Error: Missing environment variables`

**解決**:
```bash
# .env.local が存在するか確認
ls -la .env.local

# 環境変数が正しく読み込まれているか確認
npm run dev | grep SUPABASE
```

### 問題2: テスト用データベースに接続できない

**エラー**: `Error: Invalid API key`

**解決**:
1. Supabaseダッシュボードで API キーを再確認
2. `.env.local` のキーが正しいか確認
3. Supabaseプロジェクトが起動しているか確認

### 問題3: Staging環境が本番データを使っている

**確認方法**:
```bash
# Vercelダッシュボード → Settings → Environment Variables
# Preview環境の NEXT_PUBLIC_SUPABASE_URL を確認
```

**解決**:
1. Preview環境の環境変数をテスト用Supabaseに変更
2. 再デプロイ

### 問題4: 本番とテストのデータが混在している

**確認方法**:
```bash
# ブラウザの開発者ツール → Console
console.log(process.env.NEXT_PUBLIC_SUPABASE_URL)
console.log(process.env.NEXT_PUBLIC_ENV)
```

**解決**:
1. `.env.local` の内容を確認
2. ブラウザのキャッシュをクリア
3. 開発サーバーを再起動

### 問題5: ノートPCとデスクトップPCで挙動が違う

**原因**: 環境変数の違い

**解決**:
```bash
# 両方のPCで環境変数を確認
cat .env.local

# 内容が一致しているか確認
```

---

## セキュリティのベストプラクティス

### 1. `.env.local` を絶対にコミットしない

```bash
# .gitignore に含まれているか確認
cat .gitignore | grep .env.local
```

### 2. テスト用データベースのパスワードを定期的に変更

Supabaseダッシュボード → Settings → Database → Reset Database Password

### 3. service_role_key は最小限の使用に留める

- テスト環境でのみ使用
- 本番環境では極力使用しない

### 4. 本番データベースへのアクセスを制限

- 開発時は基本的にテスト用データベースを使用
- 本番データベースは読み取り専用で確認のみ

---

## Quick Reference

### コマンド一覧

```bash
# 環境確認
echo $NEXT_PUBLIC_ENV
npm run dev | grep SUPABASE

# ブランチ確認
git branch

# 環境切り替え
git checkout staging  # テスト環境
git checkout main     # 本番環境

# Staging環境にデプロイ
git push origin staging

# 本番環境にデプロイ
git push origin main
```

### URL一覧

| 環境 | URL | データベース | 用途 |
|------|-----|-------------|------|
| ローカル開発 | http://localhost:3000 | テスト用Supabase | 開発・テスト |
| Staging | https://hashpilot-staging.vercel.app | テスト用Supabase | 検証 |
| 本番 | https://hashpilot.net | 本番Supabase | 本番運用 |

### 環境変数チェックリスト

- [ ] `.env.local` を作成した
- [ ] テスト用SupabaseのURLとキーを設定した
- [ ] `NEXT_PUBLIC_ENV=development` を設定した
- [ ] Vercel Staging環境変数を設定した
- [ ] Vercel Production環境変数を確認した

---

## 次のステップ

1. ✅ このドキュメントを読む
2. ⬜ テスト用Supabaseプロジェクトを作成
3. ⬜ データベーススキーマをコピー
4. ⬜ テストデータを投入
5. ⬜ `.env.local` を作成
6. ⬜ ローカルで開発サーバーを起動して動作確認
7. ⬜ Vercel Staging環境変数を設定
8. ⬜ stagingブランチにプッシュしてStaging環境で確認

---

最終更新: 2025年11月2日
