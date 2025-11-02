# Staging環境セットアップガイド

## 概要
- **本番環境**: https://hashpilot.net (mainブランチ)
- **テスト環境**: https://hashpilot-staging.vercel.app (stagingブランチ)

## セットアップ手順

### 1. ブランチ構成
```bash
# 現在のブランチ確認
git branch

# stagingブランチに切り替え
git checkout staging

# mainブランチに切り替え
git checkout main
```

### 2. Vercelでのプロジェクト設定

#### プロジェクト: hashpilot

**Production設定（本番環境）:**
- Branch: `main`
- Domain: `hashpilot.net`
- Environment Variables:
  ```
  NEXT_PUBLIC_ENV=production
  NEXT_PUBLIC_SITE_URL=https://hashpilot.net
  NEXT_PUBLIC_SUPABASE_URL=https://soghqozaxfswtxxbgeer.supabase.co
  NEXT_PUBLIC_SUPABASE_ANON_KEY=(your_key)
  SUPABASE_SERVICE_ROLE_KEY=(your_key)
  NEXT_PUBLIC_SYSTEM_PREPARING=false
  NEXT_PUBLIC_SHOW_TEST_NOTICE=false
  ```

**Preview設定（テスト環境）:**
- Branch: `staging`
- Domain: `hashpilot-staging.vercel.app` (または `stg.hashpilot.net`)
- Environment Variables:
  ```
  NEXT_PUBLIC_ENV=staging
  NEXT_PUBLIC_SITE_URL=https://hashpilot-staging.vercel.app
  BASIC_AUTH_USER=admin
  BASIC_AUTH_PASSWORD=(設定する強力なパスワード)
  NEXT_PUBLIC_SUPABASE_URL=https://soghqozaxfswtxxbgeer.supabase.co
  NEXT_PUBLIC_SUPABASE_ANON_KEY=(your_key)
  SUPABASE_SERVICE_ROLE_KEY=(your_key)
  NEXT_PUBLIC_SYSTEM_PREPARING=true
  NEXT_PUBLIC_SHOW_TEST_NOTICE=true
  ```

### 3. Vercel設定方法

1. **Vercelダッシュボード**にログイン
2. プロジェクト `hashpilot` を選択
3. **Settings** → **Git** → **Production Branch** を `main` に設定
4. **Settings** → **Domains** でドメイン設定
   - `hashpilot.net` → Production (main)
   - `hashpilot-staging.vercel.app` → Preview (staging)
5. **Settings** → **Environment Variables** で上記の環境変数を設定
   - Production用とPreview用を分けて設定

### 4. ベーシック認証

**Staging環境のみ有効:**
- ユーザー名: `admin` (BASIC_AUTH_USERで変更可能)
- パスワード: 環境変数 `BASIC_AUTH_PASSWORD` で設定

**本番環境:**
- ベーシック認証は無効（環境変数を設定しない）

### 5. 開発フロー

#### テスト環境で開発・テスト
```bash
# 1. stagingブランチに切り替え
git checkout staging

# 2. 機能を開発
# コードを修正...

# 3. コミット
git add .
git commit -m "新機能追加"

# 4. プッシュ（テスト環境に自動デプロイ）
git push origin staging

# 5. https://hashpilot-staging.vercel.app でテスト
```

#### テストOK → 本番環境に反映
```bash
# 1. mainブランチに切り替え
git checkout main

# 2. stagingの変更をマージ
git merge staging

# 3. プッシュ（本番環境に自動デプロイ）
git push origin main

# 4. https://hashpilot.net で確認
```

#### ロールバック（問題があった場合）
```bash
# 1つ前のコミットに戻す
git revert HEAD
git push origin main
```

### 6. カスタムドメイン設定（オプション）

Staging環境に `stg.hashpilot.net` を使う場合:

1. **DNS設定（お名前.comなど）:**
   ```
   Type: CNAME
   Name: stg
   Value: cname.vercel-dns.com
   ```

2. **Vercelでドメイン追加:**
   - Settings → Domains → Add
   - `stg.hashpilot.net` を入力
   - Branchを `staging` に設定

3. **SSL証明書:** 自動で取得・更新される

### 7. 注意事項

**データベース:**
- デフォルトでは本番と同じSupabaseを使用
- テスト用データベースを使いたい場合は、別のSupabaseプロジェクトを作成して環境変数を変更

**メール送信:**
- テスト環境でのメール送信に注意（本番ユーザーにメールが送られないよう確認）

**決済・外部API:**
- テスト環境では必ずサンドボックス/テストモードを使用

### 8. トラブルシューティング

**ベーシック認証が表示されない:**
- Vercelの環境変数 `NEXT_PUBLIC_ENV=staging` が設定されているか確認
- `BASIC_AUTH_USER` と `BASIC_AUTH_PASSWORD` が設定されているか確認

**デプロイされない:**
- Vercelのデプロイログを確認
- ブランチ名が正しいか確認

**環境変数が反映されない:**
- Vercelで環境変数を変更した後、再デプロイが必要
- Deployments → 最新のデプロイ → Redeploy

---

## Quick Reference

| 環境 | ブランチ | URL | ベーシック認証 |
|------|---------|-----|---------------|
| 本番 | main | https://hashpilot.net | なし |
| テスト | staging | https://hashpilot-staging.vercel.app | あり |

## コマンド早見表

```bash
# Staging環境で開発
git checkout staging
git add .
git commit -m "修正内容"
git push origin staging

# 本番環境に反映
git checkout main
git merge staging
git push origin main

# ブランチ確認
git branch

# 変更履歴確認
git log --oneline -10
```
