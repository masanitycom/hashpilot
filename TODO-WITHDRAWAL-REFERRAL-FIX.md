# 月末出金に紹介報酬を含める修正

作成日: 2025-12-10

## 手動対応履歴

- **2025年11月分**: 手動で紹介報酬を計算し、個人利益と合算して送金済み

## 問題点

現在の月末出金システムは**個人利益（日利）のみ**を出金対象にしていて、**紹介報酬が含まれていない**。

USDTフェーズのユーザーは紹介報酬も出金できるべき。

## 現状の動作

### affiliate_cycleテーブル

| フィールド | 現在の役割 |
|------------|------------|
| `cum_usdt` | 紹介報酬の累積額（フェーズ管理用） |
| `available_usdt` | 出金可能な金額（**個人利益のみ**） |
| `phase` | USDT / HOLD |

### 日利処理（process_daily_yield_v2）

- 個人利益（60%）→ `available_usdt`に加算
- 紹介報酬（30%）→ 月末に`cum_usdt`に加算（`available_usdt`には入らない）
- NFT自動付与時の$1,100 → `available_usdt`に加算

### NFTサイクルの仕様

| フェーズ | 条件 | 紹介報酬の扱い |
|----------|------|----------------|
| USDTフェーズ | cum_usdt < $1,100 | 即時受取可能 |
| HOLDフェーズ | cum_usdt >= $1,100 | 出金不可（次のNFT付与待ち） |

## 解決策

### 新規カラム追加

`affiliate_cycle`テーブルに`withdrawn_referral_usdt`カラムを追加：

```sql
ALTER TABLE affiliate_cycle
ADD COLUMN withdrawn_referral_usdt NUMERIC DEFAULT 0;
```

| フィールド | 役割 |
|------------|------|
| `cum_usdt` | フェーズ管理用（リセットしない、紹介報酬が入るたびに加算し続ける） |
| `withdrawn_referral_usdt`（新規） | 出金済みの紹介報酬累計 |

### 出金可能額の計算

```
出金可能な紹介報酬 = cum_usdt - withdrawn_referral_usdt
（ただしUSDTフェーズの場合のみ）

出金可能額 = available_usdt + (USDTフェーズなら 出金可能な紹介報酬)
```

### 具体例

1. **初期状態**: cum_usdt = $0, withdrawn = $0
2. **紹介報酬$500獲得**: cum_usdt = $500, withdrawn = $0 → 出金可能 $500（USDTフェーズ）
3. **$500出金**: cum_usdt = $500, withdrawn = $500 → 出金可能 $0
4. **紹介報酬$700獲得**: cum_usdt = $1,200, withdrawn = $500 → HOLDフェーズ、出金不可
5. **紹介報酬$1,000獲得**: cum_usdt = $2,200 → NFT自動付与 → cum_usdt = $1,100, withdrawn = $500

## 修正が必要な箇所

### 1. データベース

- [ ] `affiliate_cycle`テーブルに`withdrawn_referral_usdt`カラム追加

### 2. 月末出金処理

- [ ] 出金申請作成時に紹介報酬を含める
- [ ] `complete_withdrawals_batch`関数で`withdrawn_referral_usdt`を更新

### 3. ユーザーダッシュボード（/withdrawal）

- [ ] 出金状況に個人利益と紹介報酬を分けて表示
- [ ] 出金可能額の計算を修正

### 4. 管理画面（/admin/withdrawals）

- [ ] 個人利益と紹介報酬を分けて表示
- [ ] 出金可能額の計算を修正
- [ ] USDTフェーズのユーザーは紹介報酬も含めた金額を表示
- [ ] HOLDフェーズのユーザーは個人利益のみ表示（紹介報酬は出金不可と明示）
- [ ] **フェーズ（USDT/HOLD）を一覧のカラムに追加**
  - USDTフェーズ: 💰 USDT（緑）
  - HOLDフェーズ: 🔒 HOLD（オレンジ）
- [ ] 出金可能な紹介報酬額を表示（USDTフェーズのみ）

## 関連ファイル

- `scripts/FIX-process-daily-yield-v2-remove-referral.sql` - 日利処理関数
- `scripts/FIX-complete-withdrawals-batch-uuid-v2.sql` - 出金完了処理関数
- `components/pending-withdrawal-card.tsx` - ユーザー出金状況表示
- `app/admin/withdrawals/page.tsx` - 管理画面出金管理
- `app/withdrawal/page.tsx` - ユーザー出金ページ
