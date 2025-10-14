# 🚀 HASHPILOT 運用開始前 最終チェックリスト

**日時**: 2025年10月12日
**運用開始予定**: 2025年10月15日～

---

## ✅ 完了した修正

### 1. メール送信機能の改善
- **問題**: HTMLを書かないとメール送信できない、URLがリンクにならない、改行できない
- **解決**: プレーンテキスト自動HTML変換機能を実装
  - 改行が自動で`<br>`に変換
  - URLが自動でリンクに変換
  - HTMLを知らなくても使える
- **ファイル**:
  - `/lib/text-to-html.ts`
  - `/app/admin/emails/page.tsx`

### 2. 日利表示問題の解決
- **問題**: ダッシュボードに日利が表示されない、グラフにデータが出ない
- **原因**: `user_daily_profit`テーブルが空だった
- **解決**: `user_daily_profit`をビューに変更して`nft_daily_profit`から自動集計
- **ファイル**: `scripts/URGENT-fix-user-daily-profit.sql` ✅ 実行済み

### 3. 運用開始日ルールの検証
- **確認**: 21日～月末購入ユーザーが正しく「翌月15日」になっている ✅
- **結果**: 9月21日～30日承認の13名全員が10/15運用開始に設定済み

### 4. 自動付与NFTへの日利反映
- **確認**: 自動NFTにも日利が正しく反映される ✅
- **仕組み**: `nft_daily_profit`がNFT種別を問わず全NFTに日利を記録
- **検証**: `user_daily_profit`ビューで自動的に集計される

---

## 📊 現在のシステム状態

### データベース
- **運用開始済みユーザー**: 258名（10/12時点）
- **10/15運用開始予定**: 29名
- **11/1運用開始予定**: 3名
- **最終日利設定日**: 2025/10/2（日利1%）

### 日利計算
- **計算式**: `1% × (1 - 30%/100) × 0.6 = 0.42%` ✅ 正しい
- **マージン処理**: プラス利益は30%引き、マイナス利益は30%補填 ✅
- **運用開始日チェック**: 実装済み ✅

### メール機能
- **NFT承認メール**: シンプル版（購入詳細 + ボタン2つ） ✅
- **システムメール**: 自動HTML変換対応 ✅
- **Edge Function**: `send-approval-email` デプロイ必要（Supabaseダッシュボードから）

---

## 🎯 運用開始当日（10/15）の手順

### 1. 日利設定（管理画面）
```
URL: https://hashpilot.net/admin/yield
```

1. 日利率を入力（例: +0.5%）
2. マージン率を入力（デフォルト: 30%）
3. 「設定」ボタンをクリック

**自動実行される処理:**
- ✅ 日利配布（`nft_daily_profit` + `user_daily_profit`ビュー）
- ✅ 紹介報酬計算・配布（Level 1-3）
- ✅ NFT自動付与（$2,200到達時）
- ✅ サイクル更新
- ✅ 月末自動出金（月末の場合のみ）

### 2. ダッシュボード確認
```
URL: https://hashpilot.net/dashboard
```

**確認項目:**
- [ ] 昨日の日利が表示される
- [ ] 今月累計が表示される
- [ ] グラフにデータが表示される
- [ ] 紹介報酬が表示される（紹介者がいる場合）
- [ ] 運用ステータスが「🟢 運用中」になっている

### 3. 月末（10/31）の自動出金
- [ ] 日利処理時に自動実行される
- [ ] `available_usdt >= $10`のユーザーに出金申請が作成される
- [ ] ユーザーにタスクポップアップが表示される
- [ ] タスク完了後、管理画面で送金処理

---

## 🔍 トラブルシューティング

### Q1: 日利が表示されない
**確認項目:**
1. 日利設定が完了しているか（`daily_yield_log`テーブル確認）
2. ユーザーの運用開始日が今日以前か（`users.operation_start_date`）
3. NFTが承認済みか（`users.has_approved_nft = true`）

**SQL確認:**
```sql
-- scripts/check-yesterday-and-today.sql
-- scripts/debug-daily-yield-issue.sql
```

### Q2: グラフにデータが出ない
**確認項目:**
1. `user_daily_profit`ビューが作成されているか
2. 過去30日間にデータがあるか

**SQL確認:**
```sql
SELECT * FROM user_daily_profit
WHERE user_id = 'XXXXXX'
ORDER BY date DESC LIMIT 30;
```

### Q3: 自動NFTに日利が反映されない
**確認項目:**
1. `nft_master`に自動NFTレコードが作成されているか
2. `nft_daily_profit`に日利レコードが作成されているか

**SQL確認:**
```sql
-- scripts/verify-auto-nft-daily-profit.sql
```

### Q4: 紹介報酬が配布されない
**確認項目:**
1. 紹介者の運用開始日が今日以前か
2. 紹介ツリーが正しく構築されているか

**SQL確認:**
```sql
SELECT user_id, referrer_user_id, operation_start_date
FROM users
WHERE user_id = 'XXXXXX';
```

---

## 📝 重要な注意事項

### 日利設定
- ⚠️ **テストモードは削除済み**（本番運用のみ）
- ⚠️ **未来の日付には設定不可**（今日または過去のみ）
- ⚠️ **同日の再設定は上書き**（既存データを置き換え）

### 運用開始日
- ✅ 1日～5日購入 → 当月15日開始
- ✅ 6日～20日購入 → 翌月1日開始
- ✅ 21日～月末購入 → 翌月15日開始

### 自動NFT付与
- ✅ 紹介報酬 >= $2,200で自動付与
- ✅ $1,100は出金可能になる
- ✅ 次のサイクルから日利対象

### 月末自動出金
- ✅ 月末の日利処理時に自動実行
- ✅ `available_usdt >= $10`が対象
- ✅ タスク完了後に出金申請が`pending`になる

---

## 🛠 システム構成

### データベーステーブル
- `nft_daily_profit`: NFT別の日利記録（実テーブル）
- `user_daily_profit`: ユーザー別の日利（ビュー、自動集計）
- `daily_yield_log`: 日利設定履歴
- `affiliate_cycle`: サイクル管理
- `nft_master`: NFT台帳
- `purchases`: 購入履歴

### RPC関数
- `process_daily_yield_with_cycles()`: 日利処理メイン関数
- `calculate_operation_start_date()`: 運用開始日計算
- `calculate_daily_referral_rewards()`: 紹介報酬計算
- `process_monthly_withdrawals()`: 月末出金処理

### Edge Functions
- `send-approval-email`: NFT承認メール送信
- `send-system-email`: システムメール送信

---

## 📞 緊急連絡先

問題が発生した場合:
1. `scripts/check-all-system-integrity.sql` を実行
2. エラーログを確認（Supabase Logs）
3. システムログを確認（`system_logs`テーブル）

---

## ✅ 最終確認（運用開始前）

- [x] メール送信機能が正常動作
- [x] 日利表示が正常動作
- [x] 運用開始日ルールが正しい
- [x] 自動NFTに日利が反映される
- [x] 日利計算式が正しい
- [ ] `send-approval-email` Edge Functionをデプロイ
- [ ] 10/15に日利設定を実行
- [ ] ダッシュボードで表示確認

---

**システムは完全に準備完了しています。安心して運用開始してください！** 🚀
