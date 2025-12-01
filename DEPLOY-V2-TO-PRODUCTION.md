# V2システムの本番環境デプロイ手順

**日付**: 2025年12月1日
**目的**: V1システムの重大なバグを修正するため、V2システムに切り替える

---

## ✅ 事前確認

- [x] V2関数がテスト環境で動作確認済み
- [x] V2関数の紹介報酬計算ロジックを確認（実際の日利を使用）
- [x] `daily_yield_log_v2`テーブルが本番環境に存在
- [ ] データベースバックアップ作成
- [ ] V2関数を本番環境にデプロイ
- [ ] 環境変数を設定
- [ ] 動作確認

---

## STEP 1: データベースバックアップ

⚠️ **重要**: 必ず実行してください

```bash
# Supabase ダッシュボードから:
# Settings → Database → Backup → Create Backup
```

または、主要テーブルのバックアップ:

```sql
-- scripts/BACKUP-before-v2-migration.sql
-- 実行してバックアップSQLを取得
```

---

## STEP 2: V2関数のデプロイ

以下のSQLスクリプトを本番環境のSupabase SQL Editorで実行:

```bash
scripts/FIX-process-daily-yield-v2-complete-clean.sql
```

**実行方法:**
1. Supabase ダッシュボードにログイン
2. SQL Editor を開く
3. `FIX-process-daily-yield-v2-complete-clean.sql`の内容を貼り付け
4. 「Run」をクリック

**確認:**
```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_v2'
  AND routine_schema = 'public';
```

結果: 1行返ってくればOK

---

## STEP 3: テスト実行

V2関数が正しく動作するか、テストモードで確認:

```sql
SELECT * FROM process_daily_yield_v2(
  '2025-11-01'::DATE,  -- テスト日付（過去）
  100.00,              -- テスト金額
  true                 -- テストモード
);
```

**確認ポイント:**
- エラーが発生しないこと
- 結果に`status: 'SUCCESS'`が含まれること
- `details`に配布詳細が含まれること

---

## STEP 4: 環境変数の設定

Vercelダッシュボードで環境変数を設定:

### Production環境:

1. Vercel → hashpilot → Settings → Environment Variables
2. 「Add New」をクリック
3. 以下を追加:

```
名前: NEXT_PUBLIC_USE_YIELD_V2
値: true
環境: Production
```

4. 「Save」をクリック

### Preview環境（オプション）:

同様に、Preview環境にも設定（既に設定済みの可能性あり）

---

## STEP 5: デプロイ

環境変数を保存すると、Vercelが自動的に再デプロイします。

または、手動でデプロイ:

```bash
# ローカルから
git add .
git commit -m "feat: V2システムに切り替え"
git push origin main
```

**確認:**
- Vercel → hashpilot → Deployments
- 最新のデプロイが「Ready」になるまで待つ（約2-3分）

---

## STEP 6: 動作確認

### 6-1. 管理画面で日利設定画面を開く

https://hashpilot.net/admin/yield

**確認ポイント:**
- 「運用利益（＄）」の入力欄が表示される（V2モード）
- 「日利率（%）」と「マージン率（%）」が表示されない

### 6-2. テストデータで実行

⚠️ **注意**: 本番データでは**まだ実行しないでください**

1. 過去の日付を選択（例: 2025-11-01）
2. 運用利益を入力（例: 100.00）
3. 「設定」ボタンをクリック

**期待される動作:**
- 成功メッセージが表示される
- 「日利配布: XX名に総額$XXX.XX」
- 「紹介報酬: XX名に配布」
- 「NFT自動付与: XX名に付与」

### 6-3. データベースで確認

```sql
-- V2のログが作成されているか
SELECT * FROM daily_yield_log_v2
WHERE date = '2025-11-01'
ORDER BY created_at DESC
LIMIT 1;

-- 日利配布が記録されているか
SELECT COUNT(*), SUM(daily_profit)
FROM nft_daily_profit
WHERE date = '2025-11-01';

-- 紹介報酬が記録されているか
SELECT COUNT(*), SUM(profit_amount)
FROM user_referral_profit
WHERE date = '2025-11-01';
```

---

## STEP 7: 本番運用開始

すべての確認が完了したら、本番データで運用開始:

1. 管理画面で今日の日付を選択
2. 実際の運用利益を入力
3. 「設定」ボタンをクリック

---

## トラブルシューティング

### エラー: 「関数が見つかりません」

→ STEP 2のV2関数デプロイが失敗している可能性
→ Supabase SQL Editorでエラーメッセージを確認

### 環境変数が反映されない

→ Vercelの再デプロイが必要
→ Settings → Environment Variables で変数を確認

### V1モードのまま表示される

→ ブラウザのキャッシュをクリア
→ シークレットモードで確認

---

## ロールバック手順

万が一、V2で問題が発生した場合:

### 1. 環境変数を戻す

```
NEXT_PUBLIC_USE_YIELD_V2=false
```

または、環境変数を削除

### 2. Vercelが自動デプロイ

### 3. V1モードに戻る

---

## チェックリスト

- [ ] データベースバックアップ作成
- [ ] V2関数デプロイ（SQL実行）
- [ ] テスト実行（テストモード）
- [ ] 環境変数設定（Vercel）
- [ ] Vercel再デプロイ完了
- [ ] 管理画面でV2モード確認
- [ ] テストデータで実行
- [ ] データベース確認
- [ ] 本番運用開始

---

**最終更新**: 2025年12月1日
**ステータス**: デプロイ準備完了
