# HASHPILOT デプロイメント手順書

## 📋 目次

1. [事前チェックリスト](#事前チェックリスト)
2. [デプロイメントフロー](#デプロイメントフロー)
3. [検証手順](#検証手順)
4. [ロールバック手順](#ロールバック手順)
5. [RPC関数の同期](#rpc関数の同期)
6. [緊急時の対応](#緊急時の対応)

---

## 事前チェックリスト

### ✅ コード確認

- [ ] staging ブランチで十分にテスト済み
- [ ] すべての新機能が期待通りに動作
- [ ] エラーがコンソールに表示されない
- [ ] ビルドエラーがない (`npm run build`)

### ✅ データベース確認

- [ ] RPC関数のバージョンを確認
  ```sql
  -- 本番環境で実行
  SELECT routine_name, last_altered
  FROM information_schema.routines
  WHERE routine_name LIKE '%yield%'
  ORDER BY last_altered DESC;
  ```

- [ ] テスト環境と本番環境の RPC 関数が同じバージョン
- [ ] 必要なテーブル・カラムがすべて存在

### ✅ 環境変数確認

- [ ] Vercel の Production 環境変数が正しい
  - `NEXT_PUBLIC_ENV=production`
  - `NEXT_PUBLIC_SITE_URL=https://hashpilot.net`
  - Supabase接続情報

- [ ] Vercel の Preview 環境変数が正しい
  - `NEXT_PUBLIC_ENV=staging`
  - `NEXT_PUBLIC_SITE_URL=https://hashpilot-staging.vercel.app`
  - `BASIC_AUTH_USER=admin`
  - `BASIC_AUTH_PASSWORD=(設定済み)`

---

## デプロイメントフロー

### ステップ 1: staging で最終確認

```bash
# staging ブランチに切り替え
git checkout staging

# 最新の状態を確認
git pull origin staging

# テスト環境で動作確認
# https://hashpilot-staging.vercel.app で確認
```

**確認項目:**
- [ ] UI が正しく表示される
- [ ] 日利設定が正常に動作（テストデータで確認）
- [ ] ダッシュボードのカード表示順序
- [ ] 今月の累積利益の内訳表示
- [ ] 昨日の確定運用報酬のタイトル

### ステップ 2: main ブランチへマージ

```bash
# main ブランチに切り替え
git checkout main

# main を最新化
git pull origin main

# staging の変更を確認
git log main..staging --oneline

# マージ前に差分を確認（重要！）
git diff main..staging
```

**⚠️ 重要な確認ポイント:**
- [ ] V2 システムの変更が含まれていないか？
- [ ] 意図しない変更が含まれていないか？
- [ ] RPC関数のパラメータ形式が正しいか？
  - `yield_rate`: パーセント値（0.535）
  - `margin_rate`: 小数値（0.30）

**マージ実行:**

```bash
# 安全なマージ（fast-forward禁止）
git merge --no-ff staging -m "chore: staging環境の変更を本番環境に適用

変更内容:
- 今月の累積利益に個人利益・紹介報酬の内訳表示
- その他のUI改善"

# プッシュ
git push origin main
```

### ステップ 3: Vercel でのデプロイ確認

1. Vercel ダッシュボードで自動デプロイを確認
2. デプロイログにエラーがないか確認
3. ビルドが成功したことを確認

---

## 検証手順

### 即時確認（デプロイ後5分以内）

```bash
# 本番環境にアクセス
open https://hashpilot.net
```

**確認項目:**
1. [ ] トップページが表示される
2. [ ] ログインできる
3. [ ] ダッシュボードが表示される
4. [ ] エラーメッセージが表示されない

### 詳細確認（デプロイ後30分以内）

#### 1. 管理画面の日利設定

```
URL: https://hashpilot.net/admin/yield
```

- [ ] 日付選択が正常
- [ ] 日利率入力が正常（パーセント形式）
- [ ] マージン率入力が正常（パーセント形式）
- [ ] 設定ボタンが動作
- [ ] エラーが表示されない

**テスト実行（少額で）:**
```
日付: 今日の日付
日利率: 0.1
マージン率: 30
```

- [ ] 成功メッセージが表示される
- [ ] 処理詳細が表示される
- [ ] 履歴に記録される

**確認SQL:**
```sql
-- 日利履歴を確認
SELECT * FROM daily_yield_log
WHERE date = CURRENT_DATE
ORDER BY created_at DESC LIMIT 1;

-- ユーザー利益を確認
SELECT user_id, daily_profit
FROM nft_daily_profit
WHERE date = CURRENT_DATE
LIMIT 5;
```

#### 2. ダッシュボード UI

```
URL: https://hashpilot.net/dashboard
```

**カード表示順序:**
- [ ] 1番目: 今月の累積利益
- [ ] 2番目: 昨日の確定運用報酬
- [ ] 3番目: 累積USDT

**今月の累積利益カード:**
- [ ] 合計金額が表示される
- [ ] 「2025年11月の累積利益」と表示される
- [ ] 内訳が表示される:
  - [ ] 個人利益: $X.XXX
  - [ ] 紹介報酬: $X.XXX

**昨日の確定運用報酬カード:**
- [ ] タイトル「昨日の確定運用報酬」
- [ ] 金額が表示される
- [ ] ユーザー受取率が表示される

#### 3. ブラウザコンソール確認

- [ ] エラーがない
- [ ] 警告が最小限

---

## ロールバック手順

### 緊急ロールバック（本番環境で問題発生時）

**ステップ 1: 前回の動作確認済みコミットを特定**

```bash
# コミット履歴を確認
git log --oneline -10

# 前回の動作確認済みコミット（例: 64bf838）
```

**ステップ 2: ロールバック実行**

```bash
# main ブランチに切り替え
git checkout main

# 特定のコミットに戻す
git reset --hard 64bf838

# 強制プッシュ（本番環境のみ、慎重に！）
git push -f origin main
```

**⚠️ 注意:**
- 強制プッシュは本番環境が完全に壊れた場合のみ
- 他の開発者に事前通知
- 必ずコミットハッシュをバックアップ

### 部分的なロールバック

特定のファイルのみロールバックする場合:

```bash
# 特定のファイルを前回のバージョンに戻す
git checkout 64bf838 -- app/admin/yield/page.tsx

# コミット
git commit -m "fix: 日利設定ページを前回のバージョンに戻す"

# プッシュ
git push origin main
```

---

## RPC関数の同期

### テスト環境 → 本番環境への RPC 関数同期

#### ステップ 1: テスト環境から関数定義を取得

```sql
-- テスト環境の Supabase SQL Editor で実行
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';
```

#### ステップ 2: 関数定義を保存

結果を `scripts/sync-rpc-function-YYYY-MM-DD.sql` として保存

#### ステップ 3: 本番環境で実行

1. 本番環境の Supabase ダッシュボードにログイン
2. SQL Editor を開く
3. 保存したスクリプトを実行
4. 実行結果を確認

#### ステップ 4: 動作確認

```sql
-- 本番環境で確認
SELECT
  routine_name,
  last_altered,
  specific_name
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';
```

**テスト実行:**
```sql
SELECT * FROM process_daily_yield_with_cycles(
  p_date := CURRENT_DATE,
  p_yield_rate := 0.1,
  p_margin_rate := 0.30,
  p_is_test_mode := true,  -- テストモード！
  p_skip_validation := false
);
```

- [ ] エラーが発生しない
- [ ] 期待通りの結果が返る
- [ ] テストモードで実行（本番データに影響なし）

---

## 緊急時の対応

### 問題が発生した場合の優先順位

#### 1. ユーザーへの影響度を確認

**最優先（即時対応）:**
- [ ] ログインできない
- [ ] ダッシュボードが表示されない
- [ ] 残高表示が異常
- [ ] 出金処理に影響

**高優先（1時間以内）:**
- [ ] 日利設定ができない
- [ ] 管理画面が動作しない
- [ ] UI表示の不具合

**中優先（当日中）:**
- [ ] 軽微なUI表示の問題
- [ ] パフォーマンスの低下

#### 2. 問題の切り分け

**フロントエンドの問題:**
- ブラウザコンソールのエラーを確認
- → ロールバックで対応

**バックエンドの問題:**
- Supabase のログを確認
- RPC関数のエラーを確認
- → RPC関数のロールバック or 修正

**データの問題:**
- データベースの整合性を確認
- → 修正スクリプト作成・実行

#### 3. 連絡・記録

- [ ] 問題の内容を記録
- [ ] 対応内容を記録
- [ ] 再発防止策を記録

---

## チェックリストサマリー

### デプロイ前（必須）

- [ ] staging で十分にテスト済み
- [ ] RPC関数のバージョン確認
- [ ] 環境変数の確認
- [ ] `git diff main..staging` で差分確認

### デプロイ時（必須）

- [ ] `git merge --no-ff` で安全なマージ
- [ ] Vercel のビルド成功確認

### デプロイ後（必須）

- [ ] トップページ表示確認
- [ ] ログイン確認
- [ ] ダッシュボード表示確認
- [ ] 日利設定動作確認（少額テスト）

### 問題発生時（必須）

- [ ] ユーザーへの影響度を判断
- [ ] 必要に応じてロールバック
- [ ] 問題と対応を記録

---

## 付録: よくある問題と解決方法

### 問題 1: マージン率のバリデーションエラー

**エラーメッセージ:**
```
マージン率は0%から100%の範囲で設定してください
```

**原因:**
RPC関数が期待する形式と異なる値が送信されている

**解決方法:**
```typescript
// app/admin/yield/page.tsx
const marginValue = Number.parseFloat(marginRate) / 100  // 30 → 0.30
```

### 問題 2: NFT ID制約違反

**エラーメッセージ:**
```
null value in column "nft_id" of relation "nft_daily_profit" violates not-null constraint
```

**原因:**
RPC関数が NFT ID を指定せずに `nft_daily_profit` にレコード挿入

**解決方法:**
`scripts/URGENT-FIX-production-rpc-nft-id.sql` を実行

### 問題 3: V2 システムが本番環境に混入

**症状:**
日利設定画面が金額入力になっている

**原因:**
staging から main へのマージ時に V2 の変更が含まれた

**解決方法:**
```bash
# app/admin/yield/page.tsx を前回のバージョンに戻す
git checkout <前回のコミット> -- app/admin/yield/page.tsx
git commit -m "fix: V2システムの混入を修正、V1に戻す"
git push origin main
```

---

最終更新: 2025年11月17日
