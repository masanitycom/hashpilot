# HashPilot 報酬計算システム詳細仕様書

## 1. 基本報酬計算ロジック

### 1.1 日利計算の基本式

\`\`\`
ユーザー日利 = NFT保有数 × 1000 USDT × 日利率 × (1 - 会社マージン率)
\`\`\`

**例:**
- NFT保有数: 3枚
- 日利率: 8%
- 会社マージン率: 30%
- 計算: 3 × 1000 × 0.08 × (1 - 0.30) = 3 × 1000 × 0.08 × 0.70 = 168 USDT

### 1.2 会社マージン計算

\`\`\`
会社取り分 = NFT保有数 × 1000 USDT × 日利率 × 会社マージン率
\`\`\`

**例:**
- 同上条件で: 3 × 1000 × 0.08 × 0.30 = 72 USDT

## 2. 紹介報酬計算システム

### 2.1 紹介報酬の基本ルール

| レベル | 報酬率 | 対象 |
|--------|--------|------|
| L1 (直接紹介) | 25% | 紹介したユーザーの日利に対して |
| L2 (2段階目) | 10% | 紹介したユーザーの日利に対して |
| L3 (3段階目) | 5% | 紹介したユーザーの日利に対して |

### 2.2 紹介報酬計算式

\`\`\`
L1紹介報酬 = 直接紹介者の日利 × 25%
L2紹介報酬 = 2段階目紹介者の日利 × 10%
L3紹介報酬 = 3段階目紹介者の日利 × 5%
\`\`\`

### 2.3 紹介報酬計算例

**シナリオ:**
- ユーザーA → ユーザーB → ユーザーC → ユーザーD
- 全員NFT 2枚保有、日利8%、マージン30%

**各ユーザーの日利:**
\`\`\`
各ユーザー日利 = 2 × 1000 × 0.08 × 0.70 = 112 USDT
\`\`\`

**ユーザーAが受け取る紹介報酬:**
\`\`\`
L1報酬 (Bから) = 112 × 0.25 = 28 USDT
L2報酬 (Cから) = 112 × 0.10 = 11.2 USDT  
L3報酬 (Dから) = 112 × 0.05 = 5.6 USDT
合計紹介報酬 = 28 + 11.2 + 5.6 = 44.8 USDT
\`\`\`

## 3. NFTサイクルシステム

### 3.1 サイクル状態管理

| 状態 | 累積額範囲 | 動作 |
|------|------------|------|
| USDT | 0 ≤ cum_usdt < 1100 | 即時受取可能 |
| HOLD | 1100 ≤ cum_usdt < 2200 | 受取保留 |
| リセット | cum_usdt ≥ 2200 | NFT自動購入 + リセット |

### 3.2 サイクル処理の詳細

**2200 USDT到達時の処理:**
1. NFT 1枚自動購入 (1100 USDT消費)
2. 残り1100 USDTを即時ユーザー残高に加算
3. cum_usdt = 0 にリセット
4. cycle_state = 'USDT' に戻す
5. cycle_count += 1

### 3.3 HOLD中の報酬処理

**HOLD状態での報酬:**
- 自己日利 → cum_usdtに加算のみ（受取なし）
- 紹介報酬 → cum_usdtに加算のみ（受取なし）
- pending_usdtは更新されない

## 4. 月次クローズ処理

### 4.1 月末処理の流れ

\`\`\`sql
-- 1. 月末確定処理
FOR each user:
  confirmed_usdt = pending_usdt  -- HOLD分は除外
  auto_nft_count = COUNT(nft_holdings WHERE type='auto_buy' AND month=prev_month)
  
  -- 2. 月次サマリー作成
  INSERT INTO monthly_summary (user_id, yyyy_mm, usdt_received, nft_autobuy_qty)
  
  -- 3. 出金キュー作成
  IF confirmed_usdt > 0 OR auto_nft_count > 0:
    INSERT INTO payout_queue (user_id, usdt, nft_qty, status='pending')
  
  -- 4. pending_usdtのみリセット（cum_usdtは維持）
  UPDATE affiliate_cycle SET pending_usdt = 0
\`\`\`

### 4.2 月次処理の重要ポイント

- **HOLD分は月末処理対象外**: cum_usdtは持ち越し
- **pending_usdtのみ確定**: 実際に受け取れる金額のみ処理
- **NFTサイクルは継続**: cycle_stateとcum_usdtは維持

## 5. 実装上の注意点

### 5.1 データベース設計

**重要なフィールド:**
\`\`\`sql
affiliate_cycle:
  - cum_usdt: NFT購入判定用累積額
  - pending_usdt: 月末確定待ち金額
  - cycle_state: 'USDT' | 'HOLD'
  - cycle_count: サイクル回数
\`\`\`

### 5.2 計算処理の順序

1. **日利計算** → user_daily_profit
2. **紹介報酬計算** → affiliate_reward  
3. **サイクル更新** → affiliate_cycle
4. **NFT自動購入判定** → nft_holdings
5. **会社利益記録** → company_daily_profit

### 5.3 エラーハンドリング

- **紹介者不在**: 報酬計算をスキップ
- **NFT保有なし**: 日利0として処理
- **サイクル状態不整合**: ログ出力して管理者通知

## 6. テストケース

### 6.1 基本計算テスト

\`\`\`javascript
// テストケース1: 基本日利計算
const nftCount = 3;
const yieldRate = 0.08;
const marginRate = 0.30;
const expected = 3 * 1000 * 0.08 * (1 - 0.30); // 168 USDT
\`\`\`

### 6.2 紹介報酬テスト

\`\`\`javascript
// テストケース2: 3段階紹介報酬
const userProfit = 112; // USDT
const l1Reward = userProfit * 0.25; // 28 USDT
const l2Reward = userProfit * 0.10; // 11.2 USDT  
const l3Reward = userProfit * 0.05; // 5.6 USDT
\`\`\`

### 6.3 サイクルテスト

\`\`\`javascript
// テストケース3: サイクル状態変更
let cumUsdt = 1050; // USDT状態
cumUsdt += 100; // 1150 → HOLD状態に変更
cumUsdt += 1100; // 2250 → NFT購入 + リセット
\`\`\`

---

**Document Owner:** @HashPilot Dev Team  
**Last Updated:** 2025-07-09  
**Status:** 実装完了・テスト準備中
