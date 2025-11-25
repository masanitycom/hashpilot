# テスト環境セットアップ手順

## 方法1: ローカルSupabase（推奨・最速）

### 1. Supabase CLIのインストール
```bash
npm install -g supabase
```

### 2. Dockerのインストール（必須）
- Docker Desktop for Windowsをインストール
- https://www.docker.com/products/docker-desktop/

### 3. ローカルSupabaseの起動
```bash
cd /mnt/d/HASHPILOT
supabase init
supabase start
```

### 4. 本番データのダンプとインポート
```bash
# 本番DBからエクスポート
npx supabase db dump --db-url "postgresql://postgres:[PASSWORD]@db.soghqozaxfswtxxbgeer.supabase.co:5432/postgres" > test-data.sql

# ローカルにインポート
npx supabase db reset
psql postgresql://postgres:postgres@localhost:54322/postgres < test-data.sql
```

### 5. `.env.test.local` を作成
```bash
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
NEXT_PUBLIC_SYSTEM_PREPARING=false
NEXT_PUBLIC_SHOW_TEST_NOTICE=true
```

### 6. テスト環境で起動
```bash
cp .env.test.local .env.local
npm run dev
```

---

## 方法2: Supabase新規テストプロジェクト

### 1. Supabaseで新規プロジェクト作成
- https://app.supabase.com
- プロジェクト名: `hashpilot-test`
- リージョン: Tokyo (ap-northeast-1)

### 2. 本番スキーマのエクスポート
```bash
# scripts/export-production-schema.sql を本番Supabaseで実行
# すべての関数定義を取得
```

### 3. テストプロジェクトにインポート
- 取得したCREATE TABLE文を実行
- 取得したCREATE FUNCTION文を実行
- RLSポリシーを設定

### 4. `.env.test.local` を作成
```bash
NEXT_PUBLIC_SUPABASE_URL=https://[TEST_PROJECT_ID].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[TEST_ANON_KEY]
NEXT_PUBLIC_SYSTEM_PREPARING=false
NEXT_PUBLIC_SHOW_TEST_NOTICE=true
```

### 5. テスト環境で起動
```bash
cp .env.test.local .env.local
npm run dev
```

---

## テスト → 本番の切り替え

### テスト環境に切り替え
```bash
cp .env.test.local .env.local
npm run dev
```

### 本番環境に切り替え
```bash
cp .env.production.local .env.local
npm run dev
```

---

## 注意事項

1. **`.env.local` はgitignore済み**: 誤って本番環境の認証情報をコミットしないため
2. **テストデータの分離**: テスト環境では本番データに影響を与えない
3. **関数の更新**: 新しいRPC関数をテストした後、本番に適用

---

## 現在の状況

- ✅ `.env.local.example` 作成済み
- ✅ `.env.staging.example` 作成済み
- ✅ `.env.production.example` 作成済み
- ✅ `.env.development.example` 作成済み
- ❌ テスト用Supabaseプロジェクト未作成
- ❌ ローカルSupabase未セットアップ

---

## 次のステップ

どちらの方法でテスト環境を作りますか？

1. **ローカルSupabase**（推奨）: Dockerが必要だが、最速で完全なテスト環境
2. **新規Supabaseプロジェクト**: Dockerなし、クラウドベース、本番に近い環境
