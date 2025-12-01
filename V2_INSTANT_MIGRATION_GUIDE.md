# V2システム 瞬間移行ガイド

## 🚀 移行準備（完了済み）

### ✅ STEP 1: V2テーブル作成（完了）
```sql
-- 本番環境に適用済み
daily_yield_log_v2
```

### ✅ STEP 2: V2 RPC関数作成（完了）
```sql
-- 本番環境に適用済み
process_daily_yield_v2(DATE, NUMERIC, BOOLEAN)
```

### ✅ STEP 3: user_daily_profit対応（完了）
```sql
-- 実行するファイル（V1に影響なし）
scripts/FIX-process-daily-yield-v2-add-user-daily-profit.sql
```

**このSQLを本番環境で実行してください。**

---

## ⚡ 移行当日の作業（5分で完了）

### 前提条件
- V1で月末処理テストが成功していること（12/1実施）
- V2関数の修正が本番環境に適用済みであること

### 移行手順

#### STEP 1: 環境変数の追加（30秒）

`.env.local`に以下を追加：
```bash
# V2システムを使用
NEXT_PUBLIC_USE_YIELD_V2=true
```

#### STEP 2: コード変更なし（0秒）

管理画面UIは既にV1/V2両対応になっています。
環境変数だけで切り替わります。

#### STEP 3: デプロイ（2分）

```bash
git add .
git commit -m "feat: V2システムに移行"
git push origin main
```

Vercelが自動デプロイします。

#### STEP 4: 動作確認（2分）

1. https://hashpilot.net/admin/yield にアクセス
2. 金額入力フィールドが表示されることを確認
3. テスト日利を入力（小さい金額で）
4. ユーザーダッシュボードで表示確認

---

## 🔄 V1に戻す方法（万が一の場合）

### 即座に戻す（1分）

```bash
# .env.localを編集
NEXT_PUBLIC_USE_YIELD_V2=false

git add .
git commit -m "revert: V1システムに戻す"
git push origin main
```

V1関数は残っているため、即座に元に戻ります。

---

## 📊 V1とV2の比較

| 項目 | V1（利率％） | V2（金額$） |
|------|-------------|------------|
| 入力項目 | 日利率％、マージン率％ | 運用利益$ |
| 計算式 | NFT数 × $1000 × 利率 × (1-マージン) × 0.6 | 金額$ / NFT数 × 0.6 |
| user_daily_profit | ✅ 作成 | ✅ 作成（修正済み） |
| ダッシュボード | ✅ 互換 | ✅ 互換 |
| 月末処理 | ✅ 統合 | ✅ 統合 |
| 紹介報酬 | ✅ Level 1-3 | ✅ Level 1-3 |
| NFT自動付与 | ✅ | ✅ |

---

## ⚠️ 注意事項

### データの互換性

- **ログテーブル**: V1とV2で別々（`daily_yield_log` vs `daily_yield_log_v2`）
- **ユーザーテーブル**: 共通（`user_daily_profit`, `nft_daily_profit`, `user_referral_profit`）
- **V1とV2のデータは混在可能**（ログだけ分かれている）

### 削除機能

現在の削除機能はV1専用です。V2で入力した日利を削除する場合は、以下のSQLを直接実行：

```sql
DELETE FROM daily_yield_log_v2 WHERE date = '2025-12-XX';
DELETE FROM user_daily_profit WHERE date = '2025-12-XX';
DELETE FROM nft_daily_profit WHERE date = '2025-12-XX';
DELETE FROM user_referral_profit WHERE date = '2025-12-XX';
```

（削除機能のV2対応は後日実装予定）

---

## 🎯 移行のタイミング

### 推奨: 12/2の日利入力から

1. 12/1: V1で11/30の日利入力（月末処理テスト）
2. 12/2: V2システムに切り替え
3. 12/2: V2で12/1の日利入力（最初のV2運用）

### 理由

- 月末処理が正常に動作することをV1で確認
- V2は月初からスタート（月末処理のテストが不要）
- 次の月末（12/31）までにV2の月末処理を確認

---

## 📝 移行チェックリスト

### 事前準備（12/1まで）
- [ ] V2関数の修正を本番環境に適用
- [ ] V1で月末処理テストを実施（12/1）
- [ ] 月次紹介報酬計算の動作確認
- [ ] 月末自動出金の動作確認

### 移行当日（12/2）
- [ ] `.env.local`に`NEXT_PUBLIC_USE_YIELD_V2=true`を追加
- [ ] コミット＆プッシュ
- [ ] Vercelのデプロイ完了を確認
- [ ] 管理画面で金額入力フィールドを確認
- [ ] テスト日利を入力
- [ ] ユーザーダッシュボードで表示確認
- [ ] 成功メッセージの確認

### 移行後（12/2以降）
- [ ] V2での日利入力を継続
- [ ] 次の月末（12/31）で月末処理を確認
- [ ] V1関数は削除せず保持（バックアップ用）

---

## 🆘 トラブルシューティング

### Q: V2で入力してもダッシュボードに表示されない

**A:** `user_daily_profit`が作成されていない可能性があります。

確認方法:
```sql
SELECT * FROM user_daily_profit WHERE date = '2025-12-XX';
```

空の場合、V2関数の修正が適用されていません。
`FIX-process-daily-yield-v2-add-user-daily-profit.sql`を実行してください。

### Q: V2からV1に戻したい

**A:** 環境変数を変更してデプロイするだけです。

```bash
NEXT_PUBLIC_USE_YIELD_V2=false
```

### Q: V2で入力したデータを削除したい

**A:** 以下のSQLを直接実行してください。

```sql
-- 日付を指定
DELETE FROM daily_yield_log_v2 WHERE date = '2025-12-XX';
DELETE FROM user_daily_profit WHERE date = '2025-12-XX';
DELETE FROM nft_daily_profit WHERE date = '2025-12-XX';
DELETE FROM user_referral_profit WHERE date = '2025-12-XX';

-- affiliate_cycleのロールバック（必要な場合のみ）
-- 手動で調整が必要
```

---

## 📞 サポート

問題が発生した場合:

1. エラーメッセージを記録
2. 発生した操作を記録
3. どの日付の日利入力で発生したか記録
4. 必要に応じてV1に戻す

---

最終更新: 2025-11-30
