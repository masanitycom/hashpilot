# テスト環境クイックセットアップガイド

## 📋 前提条件
- Supabaseアカウント（無料プランでOK）
- 本番環境へのアクセス権

---

## ステップ1: テスト用Supabaseプロジェクト作成

1. **https://app.supabase.com** にアクセス
2. 「**New Project**」をクリック
3. プロジェクト設定:
   ```
   Name: hashpilot-test
   Database Password: [安全なパスワードを設定]
   Region: Tokyo (ap-northeast-1)
   Pricing Plan: Free
   ```
4. プロジェクトが作成されるまで待つ（約2分）

---

## ステップ2: スキーマのエクスポート

### 2-1. 本番Supabaseにアクセス
- https://app.supabase.com/project/soghqozaxfswtxxbgeer

### 2-2. SQL Editorを開く
- 左メニュー > 「SQL Editor」

### 2-3. エクスポートスクリプトを実行
- `scripts/export-full-schema-for-test.sql` の内容をコピー
- SQL Editorに貼り付けて実行
- 各STEPの結果を別々にコピーして保存

---

## ステップ3: テスト環境へのインポート

### 3-1. テストプロジェクトのSQL Editorを開く
- https://app.supabase.com/project/[TEST_PROJECT_ID]/sql

### 3-2. 順番にインポート

#### A. テーブル定義
1. 本番Supabase > Table Editor > 各テーブル
2. "..." > "View SQL Definition" をクリック
3. CREATE TABLE文をコピー
4. テスト環境のSQL Editorで実行

**重要なテーブル（この順番で作成）**:
1. `users`
2. `purchases`
3. `nft_master`
4. `affiliate_cycle`
5. `user_daily_profit`
6. `user_referral_profit`
7. `withdrawal_requests`
8. `buyback_requests`
9. その他のテーブル

#### B. RPC関数
- STEP 2の結果（関数定義）をテスト環境で実行

#### C. インデックス
- STEP 3の結果をテスト環境で実行

#### D. RLSポリシー
- STEP 4の結果をテスト環境で実行

---

## ステップ4: テストデータのコピー（オプション）

### 方法1: 少量のテストデータを手動作成
- ユーザー数人分のデータを手動で INSERT

### 方法2: 本番データの一部をコピー
```sql
-- テスト用ユーザー1人分のデータをコピー
INSERT INTO users SELECT * FROM users WHERE email = 'test@example.com';
INSERT INTO purchases SELECT * FROM purchases WHERE user_id = 'test-user-id';
-- 以下同様...
```

---

## ステップ5: .env.test.local を作成

プロジェクトルートに `.env.test.local` を作成:

```bash
# Test Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=https://[TEST_PROJECT_ID].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[TEST_ANON_KEY]

# System Configuration
NEXT_PUBLIC_SYSTEM_PREPARING=false
NEXT_PUBLIC_SHOW_TEST_NOTICE=true
```

**接続情報の取得方法**:
1. テストプロジェクトのダッシュボードを開く
2. 左メニュー > 「Settings」 > 「API」
3. 以下をコピー:
   - `Project URL` → `NEXT_PUBLIC_SUPABASE_URL`
   - `anon public` → `NEXT_PUBLIC_SUPABASE_ANON_KEY`

---

## ステップ6: テスト環境で起動

```bash
# テスト環境に切り替え
cp .env.test.local .env.local

# 開発サーバー起動
npm run dev
```

ブラウザで http://localhost:3000 にアクセス

---

## 環境の切り替え

### テスト環境
```bash
cp .env.test.local .env.local
npm run dev
```

### 本番環境（現在の設定）
```bash
cp .env.local.example .env.local
# 本番の接続情報を設定
npm run dev
```

---

## 📝 チェックリスト

- [ ] テスト用Supabaseプロジェクト作成完了
- [ ] テーブル定義のインポート完了
- [ ] RPC関数のインポート完了
- [ ] RLSポリシーの設定完了
- [ ] `.env.test.local` 作成完了
- [ ] テスト環境で起動確認完了

---

## 🚨 トラブルシューティング

### エラー: "relation does not exist"
- テーブルがまだ作成されていない
- テーブル作成の順序を確認（外部キー制約があるため）

### エラー: "function does not exist"
- RPC関数がまだ作成されていない
- STEP 2の結果を実行

### エラー: 認証エラー
- `.env.test.local` の接続情報を確認
- ANON_KEYが正しいか確認

---

## 📞 サポート

問題が発生した場合:
1. エラーメッセージをコピー
2. どのステップで発生したか記録
3. ブラウザのコンソールログを確認

---

**所要時間**: 約30分〜1時間
**難易度**: 中級

次のステップ: テスト環境で新機能をテストしてから本番環境に適用
