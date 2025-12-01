# ステージング環境でV2をテストしてから本番環境に適用

**重要**: 本番環境の前に、必ずステージング環境でV2をテストします。

---

## 📋 手順

### STEP 1: ステージング環境のSupabaseにV2関数をデプロイ

**テスト環境のSupabaseダッシュボード:**
- https://supabase.com/dashboard/project/YOUR_STAGING_PROJECT_ID

1. SQL Editorを開く
2. `scripts/FIX-process-daily-yield-v2-complete-clean.sql`の内容を貼り付け
3. 「Run」をクリック

**確認:**
```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_v2'
  AND routine_schema = 'public';
```

---

### STEP 2: ステージング環境の環境変数を設定

**Vercelダッシュボード:**
- https://vercel.com/YOUR_TEAM/hashpilot/settings/environment-variables

1. 「Add New」をクリック
2. 以下を入力:

```
名前: NEXT_PUBLIC_USE_YIELD_V2
値: true
環境: Preview（stagingブランチ）
```

3. 「Save」をクリック

---

### STEP 3: ステージング環境を再デプロイ

**方法1: Vercelダッシュボードから**
1. Deployments → 最新のPreviewデプロイ
2. 「...」メニュー → 「Redeploy」

**方法2: gitから**
```bash
git checkout staging
git commit --allow-empty -m "Redeploy staging with V2"
git push origin staging
```

---

### STEP 4: ステージング環境でテスト

**URL:** https://hashpilot-staging.vercel.app

#### 4-1. 管理画面を開く
https://hashpilot-staging.vercel.app/admin/yield

**確認:**
- ✅ 「運用利益（＄）」の入力欄が表示される（V2モード）
- ❌ 「日利率（%）」と「マージン率（%）」が表示されない

#### 4-2. テストデータで実行

1. 日付を選択: 2025-11-01（過去の日付）
2. 運用利益を入力: 100.00
3. 「設定」ボタンをクリック

**期待される結果:**
```
✅ 日利設定完了

処理詳細:
• 日利配布: XX名に総額$XXX.XX
• 紹介報酬: XX名に配布
• NFT自動付与: XX名に付与
• サイクル更新: XX件
```

#### 4-3. データベースで確認

ステージング環境のSupabase SQL Editorで:

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

#### 4-4. 重要: バグが修正されているか確認

**ユーザー177B83のLevel 2紹介報酬をチェック:**

```sql
-- ステージング環境で177B83が存在するか確認
SELECT user_id, email FROM users WHERE user_id = '177B83';

-- 存在する場合、Level 2紹介報酬が正しく計算されているか
SELECT
    referral_level,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_profit
FROM user_referral_profit
WHERE user_id = '177B83'
  AND date = '2025-11-01'
GROUP BY referral_level
ORDER BY referral_level;
```

**期待される動作:**
- 日利が$0の子ユーザーは紹介報酬に含まれない
- Level 2の金額が異常に高くない（子ユーザーの実際の日利 × 10%）

---

### STEP 5: ステージング環境で問題なければ本番環境へ

すべてのテストがOKなら、本番環境に適用:

1. **本番環境のSupabaseにV2関数をデプロイ**
   - `scripts/BACKUP-before-v2-migration.sql`でバックアップ
   - `scripts/FIX-process-daily-yield-v2-complete-clean.sql`を実行

2. **本番環境の環境変数を設定**
   ```
   NEXT_PUBLIC_USE_YIELD_V2=true
   環境: Production
   ```

3. **本番環境を再デプロイ**
   ```bash
   git checkout main
   git merge staging  # stagingの変更を取り込む
   git push origin main
   ```

---

## 🔧 トラブルシューティング

### ステージング環境でV2モードにならない

**原因1: 環境変数が反映されていない**
- Vercelで再デプロイが完了しているか確認
- ブラウザのキャッシュをクリア
- シークレットモードで確認

**原因2: 環境変数の設定が間違っている**
- Vercel → Environment Variables で確認
- 環境が「Preview」または「All」になっているか
- stagingブランチが対象になっているか

**原因3: コードに問題がある**
- `app/admin/yield/page.tsx`で`NEXT_PUBLIC_USE_YIELD_V2`をチェック
- コンソールでエラーが出ていないか確認

### V2関数が見つからない

```
Error: Could not find the function public.process_daily_yield_v2
```

**解決策:**
- Supabase SQL Editorで再度実行
- エラーメッセージを確認
- 関数の存在を確認:
  ```sql
  SELECT routine_name FROM information_schema.routines
  WHERE routine_name LIKE '%yield%';
  ```

---

## ✅ チェックリスト

### ステージング環境:
- [ ] V2関数をデプロイ（Supabase SQL Editor）
- [ ] 環境変数を設定（Vercel）
- [ ] 再デプロイ（Vercel）
- [ ] 管理画面でV2モード確認
- [ ] テストデータで実行
- [ ] データベースで結果確認
- [ ] バグ修正の動作確認

### 本番環境:
- [ ] データベースバックアップ
- [ ] V2関数をデプロイ
- [ ] 環境変数を設定
- [ ] 再デプロイ
- [ ] 管理画面でV2モード確認
- [ ] テストデータで実行
- [ ] 本番運用開始

---

**最終更新**: 2025年12月1日
**推奨手順**: ステージング → 本番の順番で実施
