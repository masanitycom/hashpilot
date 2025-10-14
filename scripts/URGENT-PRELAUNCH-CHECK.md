# 🚨 運用開始前の緊急チェック項目

## 実行日時: 2025年10月12日

---

## ⚠️ 発覚した問題

### 運用開始日計算ルールの不整合

**問題:**
- `calculate_operation_start_date()` 関数が21日～月末の購入を「翌月1日」と計算している
- 正しくは「翌月15日」であるべき

**影響範囲:**
- 9月21日～9月30日に承認されたユーザー
- これらのユーザーの運用開始日が10/1になっている可能性（本来は10/15）

---

## ✅ 実行必須のSQL（順番に実行）

### 1. 現在の状態を確認
```sql
-- scripts/verify-current-system-state.sql を実行
```

### 2. 運用開始日ルールを修正
```sql
-- scripts/fix-operation-start-date-rule-correct.sql を実行
```

**このSQLは:**
- ✅ `calculate_operation_start_date()` 関数を修正
- ✅ 既存ユーザーの `operation_start_date` を再計算
- ✅ 正しい運用開始日に更新

---

## 📋 検証項目

### A. 運用開始日ルール（3段階）

| 購入日 | 運用開始日 | テストケース |
|--------|-----------|------------|
| 1日～5日 | 当月15日 | 10/3承認 → 10/15開始 |
| 6日～20日 | 翌月1日 | 10/6承認 → 11/1開始 |
| 21日～月末 | 翌月15日 | 9/25承認 → 10/15開始 |

### B. 日利計算（運用開始済みユーザーのみ）

```sql
-- 日利処理関数が operation_start_date をチェックしているか
SELECT routine_definition
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 確認箇所:
-- ✅ Line 87-88: WHERE u.operation_start_date <= p_date
-- ✅ Line 122: WHERE u.operation_start_date <= p_date
```

### C. 紹介報酬計算（運用開始済みユーザーのみ）

```sql
-- calculate_daily_referral_rewards関数を確認
SELECT routine_definition
FROM information_schema.routines
WHERE routine_name = 'calculate_daily_referral_rewards';

-- 確認箇所:
-- ✅ 紹介者の operation_start_date チェック
```

### D. フロントエンド（運用開始前ユーザーの表示）

- [ ] ダッシュボードで運用待機中バッジが表示される
- [ ] 運用開始日までの残り日数が表示される
- [ ] 運用開始前は利益が0円と表示される

---

## 🔍 重点確認ユーザー

### 9月21日～30日承認ユーザー（影響大）

```sql
SELECT
    user_id,
    email,
    admin_approved_at::date as approved,
    operation_start_date as current_start_date,
    '2025-10-15' as correct_start_date
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') > 20
  AND p.admin_approved_at >= '2025-09-21'
  AND p.admin_approved_at < '2025-10-01';
```

**期待される結果:**
- これらのユーザーの `operation_start_date` が `2025-10-15` になっているべき

---

## 🎯 運用開始前の最終チェックリスト

### データベース
- [ ] `calculate_operation_start_date()` 関数が正しいルールで実装されている
- [ ] 既存ユーザーの `operation_start_date` が正しく更新されている
- [ ] `process_daily_yield_with_cycles()` が運用開始日をチェックしている
- [ ] `calculate_daily_referral_rewards()` が運用開始日をチェックしている

### フロントエンド
- [ ] 運用ステータスバッジが正しく表示される
- [ ] 運用開始前のユーザーは利益が表示されない
- [ ] 運用開始日までのカウントダウンが表示される

### メール
- [ ] NFT承認メールがシンプル版になっている
- [ ] `send-approval-email` Edge Functionがデプロイされている

### 管理画面
- [ ] 日利設定がRPC関数経由で実行される
- [ ] テストモードが削除されている

---

## 🚀 運用開始手順

### 1. SQLスクリプト実行（10/12実行必須）
```bash
# Supabaseダッシュボードで実行:
1. scripts/verify-current-system-state.sql
2. scripts/fix-operation-start-date-rule-correct.sql
```

### 2. Edge Function デプロイ
```bash
# Supabaseダッシュボード > Edge Functions > send-approval-email
- 「Deploy」ボタンをクリック
```

### 3. 運用開始日の確認
```bash
# 10/15に運用開始するユーザーを確認:
SELECT user_id, email, operation_start_date
FROM users
WHERE operation_start_date = '2025-10-15';
```

### 4. 日利設定（10/15以降）
```bash
# 管理画面: https://hashpilot.net/admin/yield
- 日利率を入力（例: 0.5%）
- マージン率を入力（デフォルト: 30%）
- 「設定」ボタンをクリック
```

---

## 📞 問題発生時の対応

### Q1: 運用開始日が間違っている
```sql
-- 個別ユーザーの運用開始日を手動修正:
UPDATE users
SET operation_start_date = '2025-10-15'
WHERE user_id = 'XXXXXX';
```

### Q2: 日利が配布されない
```sql
-- 運用開始日を確認:
SELECT user_id, operation_start_date, has_approved_nft
FROM users
WHERE user_id = 'XXXXXX';

-- NFTを確認:
SELECT * FROM nft_master WHERE user_id = 'XXXXXX';

-- affiliate_cycleを確認:
SELECT * FROM affiliate_cycle WHERE user_id = 'XXXXXX';
```

### Q3: 紹介報酬が配布されない
```sql
-- 紹介ツリーを確認:
SELECT user_id, referrer_user_id, operation_start_date
FROM users
WHERE user_id IN (
    SELECT user_id FROM users WHERE referrer_user_id = 'XXXXXX'
);
```

---

## 📝 備考

- **重要:** 運用開始前に必ず `fix-operation-start-date-rule-correct.sql` を実行すること
- 10/15に29名のユーザーが運用開始予定
- 既に10/1から運用開始しているユーザーは影響なし
- 運用開始日ルールはデータベース関数で自動計算される
