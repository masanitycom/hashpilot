# 🚨 重大な問題と修正手順

**作成日**: 2025年10月14日

## 📋 発見された問題

### 1. NFT買い取り承認時に affiliate_cycle が更新されない

**問題:**
- NFT買い取りを承認しても `affiliate_cycle` の NFT 枚数が減らない
- `nft_master.buyback_date` は設定されるが、`affiliate_cycle` は古いまま
- 結果: 日利計算が実際のNFT数と合わなくなる

**影響を受けたユーザー:**
- 7E0A1E: 600枚買い取り済みだが、`affiliate_cycle` では 600枚のまま
- 他にも買い取り承認したユーザーがいれば同様の問題

**原因:**
`process_buyback_request` 関数が `affiliate_cycle` を更新していない

**修正スクリプト:**
```
scripts/FIX-process-buyback-update-affiliate-cycle.sql
```

---

### 2. 7E0A1E の個人配当が $0 になる問題

**現状:**
- `affiliate_cycle.total_nft_count = 601`
- 実際の NFT 数 = 1（自動NFT 1枚のみ）
- 日利計算は 601枚で計算しようとするが、実際は1枚しかない
- 結果: `nft_daily_profit` にデータが入らず、個人配当 $0

**修正スクリプト:**
```
scripts/FIX-7E0A1E-affiliate-cycle.sql
```

---

### 3. 自動NFT購入時の個人配当計算バグ

**問題:**
- `process_daily_yield_with_cycles` 関数の STEP 2 で `total_nft_count × 1000` で再計算
- STEP 1 で既に計算済みの `nft_daily_profit` を無視
- 自動NFT購入時に不整合が発生

**修正スクリプト:**
```
scripts/FIX-personal-profit-calculation-bug.sql
```

---

### 4. 「昨日の確定日利」カードの表示バグ

**問題:**
- 「昨日の確定日利」が最新データ（10/1）を表示
- 「昨日の合計」は昨日（10/13）のデータを表示
- 表記と実際の動作が不一致

**修正:**
✅ 完了（コミット済み）
- `components/daily-profit-card.tsx` を修正
- 昨日のデータのみ取得するように変更

---

## 🔧 修正手順（順番厳守）

### ステップ 1: Supabase にログイン
1. Supabase Dashboard を開く
2. SQL Editor に移動
3. セッションが切れている場合は再ログイン

### ステップ 2: NFT買い取り関数を修正
**実行:**
```sql
-- scripts/FIX-process-buyback-update-affiliate-cycle.sql
```

**効果:**
- 今後のNFT買い取り承認時に `affiliate_cycle` が正しく更新される

### ステップ 3: 7E0A1E のデータを修正
**実行:**
```sql
-- scripts/FIX-7E0A1E-affiliate-cycle.sql
```

**効果:**
- 7E0A1E の `affiliate_cycle` が実際のNFT数（1枚）に修正される
- 次回の日利計算から正しく計算される

### ステップ 4: 個人配当計算を修正
**実行:**
```sql
-- scripts/FIX-personal-profit-calculation-bug.sql
```

**効果:**
- 自動NFT購入時も個人配当が正しく計算される
- `nft_daily_profit` から集計するようになる

### ステップ 5: データクリア（テストの場合）
**実行（任意）:**
```sql
-- scripts/CLEAR-all-daily-profit-and-auto-nft.sql
```

**効果:**
- テスト用の日利データ、自動NFT、報酬をクリア
- クリーンな状態で 10/1 からテスト可能

### ステップ 6: 日利設定とテスト
1. 管理画面（`/admin/yield`）から日利を設定
2. ダッシュボードで確認:
   - ✅ 個人配当が正しく計算される
   - ✅ 紹介報酬が正しく計算される
   - ✅ 自動NFT付与後も個人配当が正しい

---

## ⚠️ 重要な注意事項

### 他のユーザーの確認
7E0A1E 以外にも NFT 買い取り承認したユーザーがいる場合、同様に修正が必要です：

```sql
-- 全ユーザーの affiliate_cycle を実際のNFT数に修正
UPDATE affiliate_cycle ac
SET
    manual_nft_count = (
        SELECT COUNT(*)
        FROM nft_master nm
        WHERE nm.user_id = ac.user_id
          AND nm.nft_type = 'manual'
          AND nm.buyback_date IS NULL
    ),
    auto_nft_count = (
        SELECT COUNT(*)
        FROM nft_master nm
        WHERE nm.user_id = ac.user_id
          AND nm.nft_type = 'auto'
          AND nm.buyback_date IS NULL
    ),
    total_nft_count = (
        SELECT COUNT(*)
        FROM nft_master nm
        WHERE nm.user_id = ac.user_id
          AND nm.buyback_date IS NULL
    ),
    last_updated = NOW();
```

### バックアップ推奨
修正前に以下のデータをエクスポート推奨：
- `affiliate_cycle`
- `nft_master`
- `buyback_requests`

---

## 📊 検証方法

### 修正後の確認クエリ
```sql
-- 1. affiliate_cycle と実際のNFT数が一致しているか
SELECT
    ac.user_id,
    ac.total_nft_count as cycle_count,
    COUNT(nm.id) as actual_count,
    CASE
        WHEN ac.total_nft_count = COUNT(nm.id) THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.buyback_date IS NULL
GROUP BY ac.user_id, ac.total_nft_count
HAVING ac.total_nft_count != COUNT(nm.id);

-- 2. 日利データが正しく生成されているか
SELECT
    user_id,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date >= '2025-10-01'
GROUP BY user_id, date
ORDER BY user_id, date;
```

---

## 🎯 完了チェックリスト

- [ ] FIX-process-buyback-update-affiliate-cycle.sql 実行
- [ ] FIX-7E0A1E-affiliate-cycle.sql 実行
- [ ] FIX-personal-profit-calculation-bug.sql 実行
- [ ] 他のユーザーの affiliate_cycle 確認
- [ ] データクリア（テストの場合）
- [ ] 日利設定
- [ ] ダッシュボードで動作確認
- [ ] 自動NFT付与のテスト

---

**最終更新**: 2025年10月14日
