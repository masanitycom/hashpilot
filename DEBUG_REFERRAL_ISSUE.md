# 🚨 紹介報酬$0.000問題のデバッグ手順

## 現状
- ✅ データベースに7A9637と紹介者の利益データが存在
- ✅ ReferralTreeは正常に12名を認識
- ❌ ReferralProfitCardで$0.000が表示される

## デバッグ手順

### 1. ブラウザのコンソールログ確認
デベロッパーツール → Console で以下のログを確認：

```
Level 1 referrals: [...]  
Level 2 referrals: [...]
Level 3 referrals: [...]
Level 1 profits: {...}
Level 2 profits: {...}  
Level 3 profits: {...}
Calculated referral profits:
```

### 2. 予想される問題

#### 問題A: purchasesテーブルクエリエラー
`referral-profit-card.tsx` 128-135行目：
```typescript
.select(`
  user_id,
  purchases!inner(admin_approved_at)
`)
```
→ このクエリが失敗し、`eligibleUserIds`が空になっている

#### 問題B: 日付フィルターエラー  
167-172行目：
```typescript
.gte('date', monthStart)
.lte('date', monthEnd)
```
→ 7/16のデータが範囲外になっている

#### 問題C: データ型エラー
184-194行目：
```typescript
const profit = parseFloat(row.daily_profit) || 0
```
→ daily_profitが文字列で正しく変換されていない

### 3. 修正案

最も可能性の高い問題Aを修正：

```typescript
// 修正前（エラーの原因）
const { data: usersData, error: usersError } = await supabase
  .from('users')
  .select(`
    user_id,
    purchases!inner(admin_approved_at)
  `)

// 修正後（シンプル版）
const { data: usersData, error: usersError } = await supabase
  .from('users')
  .select('user_id, has_approved_nft')
  .in('user_id', userIds)
  .eq('has_approved_nft', true)
```

### 4. 即座に確認
ダッシュボードのコンソールログで以下が表示されるかチェック：
- `Error fetching user approval dates: [エラー内容]`
- `Eligible users for profit calculation: []` ← これが空の場合が問題

この修正で紹介報酬が正しく計算されるはずです。