# 紹介報酬システムの仕様変更

## 📊 仕様変更の概要

### 旧仕様（現在）❌
- 紹介報酬は**日次で計算**され、`user_referral_profit`テーブルに毎日記録される
- `affiliate_cycle.cum_usdt`に**日次で加算**される
- ユーザーダッシュボードに**累積紹介報酬**が表示される

### 新仕様（変更後）✅
- 紹介報酬は**月末にまとめて計算**される
- 日次では個人利益のみ配布
- ユーザーダッシュボードには：
  - **当月の紹介報酬**: 「月末集計後に表示されます」
  - **前月確定報酬**: 前月分の紹介報酬を表示
  - **月別利益履歴**: 個人利益と紹介報酬を月ごとに検索・表示

---

## 🔄 システム変更の詳細

### 1. データベース変更

#### 新しいテーブル: `monthly_referral_profit`
```sql
CREATE TABLE monthly_referral_profit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  year_month TEXT NOT NULL,           -- 'YYYY-MM' 形式
  referral_level INTEGER NOT NULL,    -- 1, 2, 3
  child_user_id TEXT NOT NULL,
  profit_amount DECIMAL(10,3) NOT NULL,
  calculation_date DATE NOT NULL,      -- 計算実行日（月末翌日）
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CHECK (referral_level IN (1, 2, 3)),
  CHECK (profit_amount >= 0)
);

CREATE INDEX idx_monthly_referral_user_month
ON monthly_referral_profit(user_id, year_month);

CREATE UNIQUE INDEX idx_monthly_referral_unique
ON monthly_referral_profit(user_id, year_month, referral_level, child_user_id);
```

#### 既存テーブルの扱い
- `user_referral_profit`: **日次データは残す**（履歴として）
  - 新しい日利処理では**書き込まない**
  - 既存データは削除しない（過去の記録として保持）

---

### 2. 日利処理の変更

#### V2関数の修正: `process_daily_yield_v2`

**修正前:**
```sql
-- STEP 3: 紹介報酬を計算・配布（プラスの時のみ）
IF v_distribution_dividend > 0 THEN
  FOR v_user_record IN ...
    -- 紹介報酬を計算
    INSERT INTO user_referral_profit ...
    UPDATE affiliate_cycle SET cum_usdt = cum_usdt + ...
  END LOOP;
END IF;
```

**修正後:**
```sql
-- STEP 3: 紹介報酬の計算はスキップ（月末のみ実行）
-- 日次では個人利益のみ配布
-- 紹介報酬は process_monthly_referral_profit() で月末に実行
```

---

### 3. 月末紹介報酬計算

#### 新しいRPC関数: `process_monthly_referral_profit`

```sql
CREATE OR REPLACE FUNCTION process_monthly_referral_profit(
  p_year_month TEXT  -- 'YYYY-MM' 形式
)
RETURNS TABLE(
  status TEXT,
  message TEXT,
  details JSONB
)
```

**処理内容:**
1. 指定月の全日次利益を集計（`nft_daily_profit`から）
2. ユーザーごとの月次個人利益を計算
3. 紹介報酬を計算（Level 1: 20%, Level 2: 10%, Level 3: 5%）
4. `monthly_referral_profit`に記録
5. `affiliate_cycle.cum_usdt`に加算
6. NFT自動付与チェック（cum_usdt >= $2,200）

**実行タイミング:**
- 月末の日利処理後、自動実行
- または管理画面から手動実行

---

### 4. フロントエンド変更

#### A. 紹介報酬カード（現在の累積表示）

**修正前:**
```tsx
// app/components/dashboard/referral-profit-card.tsx
<div>累積紹介報酬: ${totalReferralProfit}</div>
```

**修正後:**
```tsx
<div>
  <p className="text-muted-foreground text-sm mb-2">
    ※ 紹介報酬は月末の集計後に表示されます
  </p>
  <div className="text-2xl font-bold">
    --
  </div>
</div>
```

#### B. 前月確定報酬セクション（新規追加）

```tsx
// app/components/dashboard/last-month-profit-card.tsx
<Card>
  <CardHeader>
    <CardTitle>前月確定報酬</CardTitle>
    <CardDescription>{lastMonth}月分</CardDescription>
  </CardHeader>
  <CardContent>
    <div className="space-y-2">
      <div>個人利益: ${lastMonthPersonalProfit}</div>
      <div>紹介報酬: ${lastMonthReferralProfit}</div>
      <div className="font-bold">合計: ${lastMonthTotalProfit}</div>
    </div>
  </CardContent>
</Card>
```

#### C. 月別利益履歴セクション（新規追加）

```tsx
// app/components/dashboard/monthly-profit-history.tsx
<Card>
  <CardHeader>
    <CardTitle>月別利益履歴</CardTitle>
    <div className="flex gap-2">
      <Select value={selectedMonth} onValueChange={setSelectedMonth}>
        <SelectTrigger>
          <SelectValue placeholder="月を選択" />
        </SelectTrigger>
        <SelectContent>
          {availableMonths.map(month => (
            <SelectItem key={month} value={month}>
              {month}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Button onClick={handleSearch}>検索</Button>
    </div>
  </CardHeader>
  <CardContent>
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>年月</TableHead>
          <TableHead>個人利益</TableHead>
          <TableHead>紹介報酬</TableHead>
          <TableHead>合計</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {monthlyData.map(row => (
          <TableRow key={row.month}>
            <TableCell>{row.month}</TableCell>
            <TableCell>${row.personalProfit}</TableCell>
            <TableCell>${row.referralProfit}</TableCell>
            <TableCell className="font-bold">${row.total}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  </CardContent>
</Card>
```

---

## 🔧 実装手順

### STEP 1: V2関数のDROP+CREATE対応
```sql
-- scripts/FIX-v2-drop-and-create.sql
DROP FUNCTION IF EXISTS process_daily_yield_v2(DATE, NUMERIC, BOOLEAN);

CREATE OR REPLACE FUNCTION process_daily_yield_v2(...)
...
```

### STEP 2: 月次紹介報酬テーブル作成
```sql
-- scripts/CREATE-monthly-referral-profit-table.sql
CREATE TABLE monthly_referral_profit ...
```

### STEP 3: 月次紹介報酬計算RPC作成
```sql
-- scripts/CREATE-process-monthly-referral-profit.sql
CREATE OR REPLACE FUNCTION process_monthly_referral_profit(...)
...
```

### STEP 4: V2関数修正（紹介報酬計算を削除）
```sql
-- scripts/FIX-v2-remove-daily-referral.sql
-- STEP 3の紹介報酬計算部分をコメントアウト
```

### STEP 5: フロントエンド修正
- 紹介報酬カード: 「月末集計後」メッセージ表示
- 前月確定報酬カード: 新規作成
- 月別利益履歴: 新規作成

### STEP 6: 管理画面に月次処理ボタン追加
```tsx
// app/admin/yield/page.tsx
<Button onClick={handleMonthlyReferralCalculation}>
  月次紹介報酬を計算
</Button>
```

---

## 📅 移行計画

### フェーズ1: 準備（今日）
- [ ] 仕様書作成（このファイル）
- [ ] 新テーブル設計
- [ ] 新RPC関数設計

### フェーズ2: 実装（staging環境）
- [ ] V2関数修正（DROP+CREATE対応）
- [ ] 月次テーブル作成
- [ ] 月次RPC関数作成
- [ ] フロントエンド修正

### フェーズ3: テスト（staging環境）
- [ ] 日利処理で紹介報酬が記録されないことを確認
- [ ] 月次処理で紹介報酬が正しく計算されることを確認
- [ ] ダッシュボード表示確認

### フェーズ4: 本番適用
- [ ] 本番環境にデプロイ
- [ ] 既存データの移行（必要に応じて）

---

## ⚠️ 重要な注意事項

1. **既存データの扱い**
   - `user_referral_profit`の日次データは削除しない
   - 履歴として残す（参照のみ）

2. **affiliate_cycleの扱い**
   - `cum_usdt`: 月末に紹介報酬を加算
   - 日次では個人利益のみ`available_usdt`に加算

3. **NFT自動付与**
   - 月末の紹介報酬計算後にチェック
   - `cum_usdt >= $2,200`で自動付与

4. **後方互換性**
   - 既存の日次データは保持
   - 新システムは月次データのみ参照

---

最終更新: 2025-11-23
