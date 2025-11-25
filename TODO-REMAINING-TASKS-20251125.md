# 残タスク一覧（2025年11月25日）

## 現在の状況
✅ **完了**: UIの変更（紹介報酬を「月末集計後に表示」に変更）
- Staging環境: https://hashpilot-staging.vercel.app/dashboard
- 本番環境: https://hashpilot.net/dashboard

---

## 🚀 残りのタスク

### 1. 紹介報酬の変更による関数の修正
**目的**: 日次処理から紹介報酬計算を削除し、月次処理に移行

**実行するSQLスクリプト**:
```bash
# Staging環境（既に適用済みか確認）
scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql  # V2関数の修正（日次紹介報酬削除）
scripts/CREATE-monthly-referral-profit-table.sql       # 月次テーブル作成
scripts/CREATE-process-monthly-referral-profit.sql     # 月次計算RPC関数

# 本番環境（V1システム使用中）
# → 本番環境は後でV2システム適用時に一緒に対応
```

**注意事項**:
- Staging環境ではV2システム使用中
- 本番環境ではV1システム使用中（`process_daily_yield_with_cycles`）
- 本番環境へのV2移行時に一緒に対応

---

### 2. NFTサイクルの見直し
**確認事項**:
- ✅ NFT自動付与は`cum_usdt`（紹介報酬のみ）で計算
- ✅ 個人利益は`available_usdt`に直接加算
- ✅ サイクル閾値: $2,200

**見直しポイント**:
- 月次紹介報酬計算後のNFT自動付与タイミング
- `process_monthly_referral_profit`関数内でNFT自動付与を実行する仕様を確認

**関連ファイル**:
- `scripts/CREATE-process-monthly-referral-profit.sql` (行242-305)

---

### 3. 前月の確定履歴セクションの表示
**必要な機能**:

#### 3-1. ダッシュボードに「前月の確定報酬」セクション追加
```tsx
// app/dashboard/page.tsx
// 追加する新しいカードコンポーネント
<LastMonthProfitCard userId={userData?.user_id} />
```

**表示内容**:
- 前月の個人利益
- 前月の紹介報酬（月末集計済み）
- 前月の合計利益

#### 3-2. 過去の履歴を遡って見れるページ作成
**新規ページ**: `/app/profit-history/page.tsx`

**機能**:
- 月別の利益履歴を一覧表示
- 年月で検索・フィルタリング
- 個人利益 / 紹介報酬 / 合計を表示
- 月ごとの詳細ビュー

**使用するRPC関数**:
```sql
-- 既存の関数（scripts/CREATE-monthly-referral-profit-table.sql）
get_user_monthly_profit_history(p_user_id TEXT, p_year_month TEXT)
get_last_month_profit(p_user_id TEXT)
get_available_months(p_user_id TEXT)
```

**データソース**:
- 個人利益: `nft_daily_profit`テーブルを月別集計
- 紹介報酬: `monthly_referral_profit`テーブル（月末計算後に入る）

---

### 4. ペガサス交換者の今までの個人利益削除
**現状**: 11/3分まで個人利益が表示されている

**削除対象**:
- ペガサス交換者（`pegasus_exchange_date IS NOT NULL`）
- 個人利益のみ削除（`nft_daily_profit`）
- 紹介報酬は影響なし

**削除スクリプト作成**:
```sql
-- scripts/DELETE-pegasus-personal-profit.sql
DELETE FROM nft_daily_profit
WHERE user_id IN (
    SELECT user_id FROM users
    WHERE pegasus_exchange_date IS NOT NULL
)
AND date <= '2025-11-03';

-- affiliate_cycle.available_usdtから差し引く
UPDATE affiliate_cycle ac
SET available_usdt = available_usdt - COALESCE((
    SELECT SUM(daily_profit)
    FROM nft_daily_profit ndp
    WHERE ndp.user_id = ac.user_id
        AND ndp.user_id IN (SELECT user_id FROM users WHERE pegasus_exchange_date IS NOT NULL)
        AND ndp.date <= '2025-11-03'
), 0)
WHERE user_id IN (SELECT user_id FROM users WHERE pegasus_exchange_date IS NOT NULL);
```

**確認クエリ**:
```sql
-- 削除前に確認
SELECT
    u.user_id,
    u.email,
    u.pegasus_exchange_date,
    COUNT(ndp.id) as profit_count,
    SUM(ndp.daily_profit) as total_profit
FROM users u
LEFT JOIN nft_daily_profit ndp
    ON u.user_id = ndp.user_id
    AND ndp.date <= '2025-11-03'
WHERE u.pegasus_exchange_date IS NOT NULL
GROUP BY u.user_id, u.email, u.pegasus_exchange_date;
```

---

### 5. V2システムの完成、本番環境への適用
**V2システムとは**:
- 金額入力方式（$で入力）
- 既存のV1システム（利率％入力）と機能は同じ

**V2の現状**:
- ✅ Staging環境: V2システム使用中（`process_daily_yield_v2`）
- ❌ 本番環境: V1システム使用中（`process_daily_yield_with_cycles`）

**本番環境への適用手順**:
1. V1関数のバックアップ作成
2. V2関数を本番環境のSupabaseに適用
3. 管理画面（`app/admin/yield/page.tsx`）のRPC呼び出しを確認
4. テストユーザーで動作確認
5. 本番データで実行

**関連ファイル**:
- `scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql` - V2関数（日次紹介報酬削除版）
- `scripts/COMPARE-v1-vs-v2-systems.md` - V1/V2の比較ドキュメント

---

### 6. テスト実行 → 本番環境に移行
**テストシナリオ**:

#### 6-1. Staging環境でのテスト
```bash
# 日次処理のテスト（V2システム）
- マイナス日利での動作確認
- プラス日利での動作確認
- NFT自動付与の動作確認（cum_usdt >= $2,200）
- 紹介報酬が計算されないことを確認
```

#### 6-2. 月次処理のテスト
```sql
-- Staging環境で月次紹介報酬計算をテスト
SELECT * FROM process_monthly_referral_profit('2025-11', TRUE);  -- テストモード

-- 結果を確認
SELECT * FROM monthly_referral_profit WHERE year_month = '2025-11';
SELECT * FROM monthly_referral_profit_summary WHERE year_month = '2025-11';
```

#### 6-3. 本番環境への移行チェックリスト
- [ ] Staging環境で全機能が正常動作
- [ ] V2システムのバグがないことを確認
- [ ] 月次紹介報酬計算が正しく動作
- [ ] ペガサス交換者の個人利益削除完了
- [ ] UIが正しく表示される（前月確定報酬、履歴ページ）
- [ ] バックアップ作成
- [ ] 本番環境にV2システム適用
- [ ] 本番環境で動作確認

---

## 📋 作業の優先順位

### 高優先度（今すぐ対応）
1. ✅ UIの変更（完了）

### 中優先度（次回作業時）
1. ペガサス交換者の個人利益削除
2. 前月の確定報酬セクション追加
3. 過去の履歴ページ作成

### 低優先度（Staging環境で十分にテスト後）
1. V2システムの本番環境適用
2. 月次紹介報酬計算の本番実行

---

## 🔄 関連ドキュメント

- `NEW_REFERRAL_SPEC.md` - 月次紹介報酬の詳細仕様
- `CURRENT_STATUS_20251125.md` - 現在の作業状況（停電対策）
- `COMPARE-v1-vs-v2-systems.md` - V1/V2システムの比較

---

## ⚠️ 重要な注意事項

1. **本番環境のデータベース操作は慎重に**
   - 必ずバックアップを取る
   - テストモードで動作確認してから本番実行

2. **月次紹介報酬の初回実行**
   - 11月末（11/30または12/1）に初めて実行される
   - それまでは「月末集計後に表示」のメッセージが表示される

3. **ペガサス交換者の制限**
   - 個人利益は削除するが、紹介報酬は削除しない
   - 出金制限期間は別途管理

4. **停電対策**
   - このドキュメントで作業状況を記録
   - 各作業後にGitコミット
   - UPS（無停電電源装置）到着後も継続

---

最終更新: 2025年11月25日 10:50
次回作業: ペガサス交換者の個人利益削除から開始
