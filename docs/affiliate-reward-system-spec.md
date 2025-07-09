# HashPilot NFT Affiliate Reward System — Full Technical Specification (v2025-07-07)

## 0. Goal & Scope
HashPilot の V0 + Supabase プロジェクトに、以下の機能を追加／統合する。

- 日利入力 + 会社マージン (30% / 40%)
- ユーザー日次報酬 & 3段階紹介報酬 (25% / 10% / 5%)
- NFT 強制購入サイクル (USDT 0-1100 受取 → 1100-2200 HOLD → 2200 到達で NFT 1 枚自動購入)
- 月末クローズ & 翌月 1 日確定報酬
- 管理画面 + ユーザーダッシュボード で履歴・残高・進捗を可視化
- RLS・Edge Function・Cron を含む完全な Supabase 実装

## 1. Business Rules

| 項目 | 内容 |
|------|------|
| 日利入力 | 管理者が yield_rate (%) と margin_rate (0.30 / 0.40) を入力。 |
| 会社マージン | ユーザー利率 = yield_rate × (1 − margin_rate) 。会社取り分は監査用に別テーブルへ。 |
| 紹介報酬 | L1 25%, L2 10%, L3 5% （ユーザー利率に対して）。**USDTで支払い** |
| NFTサイクル | 0-1100 USDT → 受取。1100-2200 → HOLD。2200で NFT 1枚自動購入 (1100 USDT消費)＋残 1100 を**即時支払い**＋cum_usdt=0で次サイクル開始。 |
| 月末クローズ | 月末の日利レコードに is_month_end=true を付与。翌月 1 日 00:00 JST (UTC 15:00) のクロン |
| 確定報酬 | monthly_summary を生成し、ユーザー UI に翌月 1 日以降表示。 |
| 出金 | payout_queue に pending レコード生成。手動送金後 tx_hash 登録で paid。 |

## 1.1. NFTサイクル詳細仕様

| フェーズ | 説明 | 実装パラメータ |
|----------|------|----------------|
| **USDT-フェーズ** | 0 USDT → 1,099 USDT までは都度ユーザー残高へ即時加算。 | `cycle_state = 'USDT'`, `cum_usdt < 1100` |
| **HOLD-フェーズ** | 1,100 USDT → 2,199 USDT は受取保留。cum_usdt にだけ加算。 | `cycle_state = 'HOLD'`, `cum_usdt ≥ 1100 < 2200` |
| **2200 USDT 到達時** | - 1,100 USDT を NFT 1 枚自動購入（nft_holdings.type='auto_buy'）<br>- 残り 1,100 USDT は即座にユーザー残高へ加算<br>- cycle_state を USDT に戻し、cum_usdt = 0 で次サイクルを開始 | NFT購入 + 即時支払い + リセット |

## 1.2. HOLD フェーズ中の紹介報酬

**ルール**: 自己の日利と同じく「紹介報酬」も HOLD 対象。

- HOLD 中のユーザーには受取されず cum_usdt にのみ加算
- サイクルがリセットされた段階で、次の USDT-フェーズに入った新規報酬から受取が再開

## 1.3. NFT購入タイプの区別

| タイプ | 説明 | nft_holdings.type | 取得方法 | 表示 |
|--------|------|-------------------|----------|------|
| **手動購入NFT** | ユーザーがUSDTで直接購入したNFT | `'manual_purchase'` | 既存の購入システム | 🛒 手動購入 |
| **自動購入NFT** | サイクル2200到達時に自動購入されたNFT | `'auto_buy'` | サイクルシステム | 🔄 自動購入 |

## 1.4. フィールド定義

| フィールド | 用途 | リセット条件 |
|------------|------|--------------|
| `cum_usdt` | NFT 自動購入判定用累積額（自己+紹介、マージン差引後） | NFT 購入処理直後に 0 |
| `pending_usdt` | USDT-フェーズで「まだ月末出金されていない」金額 | 月末クローズで payout_queue へ転送時に 0 |
| `cycle_state` | 'USDT' or 'HOLD' | NFT 購入後に 'USDT' へ |

## 1.5. 月次クローズ時のサイクル処理

| ユーザー状態 | 処理内容 |
|--------------|----------|
| **HOLD 中／サイクル途中** | `cum_usdt` と `cycle_state` は そのまま持ち越し。月末クローズは `pending_usdt` だけ を payout_queue へ移し、HOLD 預かり分には手を付けない。 |
| **USDT-フェーズで残高あり** | `pending_usdt` を全額 payout_queue へ。`cum_usdt` が残っていてもリセットしない（NFT サイクル継続）。 |

## 2. Data Model

### 2-1. Core Tables

| Table | PK | Columns & Notes |
|-------|----|-----------------| 
| users | id | wallet, referrer_id, … (既存) |
| **nft_holdings** | id | **user_id, type enum('manual_purchase','auto_buy'), qty, acquired_at, purchase_amount_usd, cycle_id** |
| daily_yield_log | trade_date | yield_rate numeric, margin_rate numeric, is_month_end bool |
| user_daily_profit | (user_id,trade_date) | usdt |
| affiliate_reward | id | beneficiary_id, source_user_id, level, trade_date, usdt |
| affiliate_cycle | user_id | cycle_state enum(USDT,HOLD), cum_usdt, pending_usdt, last_switch_at, cycle_count |
| company_daily_profit | trade_date | company_usdt |
| monthly_summary | (user_id, yyyy_mm) | usdt_received, nft_autobuy_qty, generated_at |
| payout_queue | id | user_id, usdt, nft_qty, cycle_close_month, status, tx_hash |
| system_config | key | value (e.g. NFT_UNIT_USD=1100) |

### 2-2. nft_holdings テーブル詳細

\`\`\`sql
CREATE TABLE nft_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES users(user_id),
    type TEXT CHECK (type IN ('manual_purchase', 'auto_buy')),
    qty INTEGER NOT NULL DEFAULT 1,
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    purchase_amount_usd NUMERIC(10,2), -- 手動購入時の実際の支払額
    cycle_id INTEGER, -- 自動購入時のサイクル番号
    transaction_hash TEXT, -- 手動購入時のトランザクションハッシュ
    notes TEXT, -- 備考（管理者メモなど）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
\`\`\`

### 2-3. RLS Guidelines

- daily_yield_log, company_daily_profit → RLS OFF (admin-only)
- All user-scoped tables → user_id = auth.uid()
- Edge Functions use service_role key for elevated inserts/updates.

## 3. Processes & Algorithms

### 3-1. RPC: admin_post_yield

\`\`\`sql
INSERT INTO daily_yield_log (trade_date, yield_rate, margin_rate, is_month_end) 
VALUES (:d, :y, :m, :is_end) 
ON CONFLICT (trade_date) DO UPDATE 
  SET yield_rate = EXCLUDED.yield_rate,
      margin_rate = EXCLUDED.margin_rate,
      is_month_end = EXCLUDED.is_month_end;
\`\`\`

### 3-2. Daily Batch (Edge Function, runs 03:05 JST)

\`\`\`sql
-- 1. Fetch yield & margin for :yesterday
v_rate, v_margin ← daily_yield_log[yesterday]
v_net ← v_rate * (1 − v_margin)
v_company ← v_rate * v_margin

-- 2. User normal profit (手動購入・自動購入NFT両方から利益計算)
INSERT user_daily_profit
SELECT u.id, :yesterday, 
       SUM(n.qty) * 1000 * v_net as daily_profit
FROM users u 
JOIN nft_holdings n ON n.user_id = u.user_id
WHERE n.type IN ('manual_purchase', 'auto_buy')
GROUP BY u.id;

-- 3. Company profit log
INSERT company_daily_profit (:yesterday, SUM(total_nft_qty * 1000 * v_company));

-- 4. Affiliate rewards & cycle update (loop levels 1-3)
FOR each profit_row … CALL updateAffiliateCycle(upline, reward);
\`\`\`

### 3-3. Monthly Close Cron (UTC 0 15 1 * *)

\`\`\`sql
prev_month ← current_date − 1 month
ASSERT daily_yield_log WHERE is_month_end=true AND month=prev_month EXISTS

FOR each user
  -- 月末確定分のみを処理（HOLD分は除外）
  u_usdt ← pending_usdt
  n_auto ← COUNT(nft_holdings WHERE type='auto_buy' AND month=prev_month)
  UPSERT monthly_summary(user, prev_month, u_usdt, n_auto)
  IF u_usdt>0 OR n_auto>0 → INSERT payout_queue(status='pending')
  
  -- pending_usdtのみリセット、cum_usdtは維持
  UPDATE affiliate_cycle SET pending_usdt = 0 WHERE user_id = user.id
END
\`\`\`

## 4. API Endpoints (Supabase RPC)

| Name | Args | Purpose |
|------|------|---------|
| fetch_dashboard(user_uuid) | – | Return today stats, cycle, 30 latest rows, last monthly_summary |
| admin_post_yield(date, rate, margin) | – | 日利 + マージン登録 |
| admin_mark_paid(payout_id, tx_hash) | – | Mark payout paid |
| get_user_nft_holdings(user_uuid) | – | NFT保有状況（タイプ別）を取得 |

## 5. Front-End (V0) Implementation

### 5-1. User Dashboard Components

**Cards:** 今日の日利・紹介報酬 (fetch_dashboard.today_profit / affiliate_today)
**ProgressBar:** cycle.cum_usdt % 1100
**Text:** 「次の NFT 自動購入まであと ${1100 - (cum_usdt % 1100)} USDT」

**NFT保有状況表示:**
\`\`\`
🛒 手動購入NFT: 3枚 ($3,300)
🔄 自動購入NFT: 2枚 (サイクル#1, #2)
─────────────────
合計: 5枚
\`\`\`

**Tabs:**
- 日次履歴 (data.history)
- NFT履歴 (nft_holdings with type display)
- 確定報酬 (monthly_summary)
- 出金履歴 (payout_queue)

### 5-2. Admin Panel Components

| Section | Components |
|---------|------------|
| 日利入力 | Form(DatePicker, NumberInput, Select[30%/40%]) → admin_post_yield |
| サイクル一覧 | Table + Progress |
| NFT保有状況 | Table(User, Manual NFTs, Auto NFTs, Total, Cycle Status) |
| 出金待ち | Table + ActionButton(Mark Paid) |

## 6. Test Matrix

| # | Scenario | Expected |
|---|----------|----------|
| 1 | 日利10%, margin30% | user_daily_profit = total_nft_qty*1000*0.07 |
| 2 | 日利8%, margin40% | user_daily_profit = total_nft_qty*1000*0.048 |
| 3 | Cycle reaches 1100 | cycle_state→HOLD, receive stop |
| 4 | Cycle reaches 2200 | NFT+1 auto_buy (type='auto_buy'), cycle reset to 0, 1100 USDT immediate payout |
| 5 | L1/L2/L3 | 25%/10%/5% splits |
| 6 | Month close | monthly_summary & payout_queue created (pending_usdt only) |
| 7 | HOLD中の紹介報酬 | cum_usdtに加算、受取なし |
| 8 | 手動購入NFT | type='manual_purchase', transaction_hash記録 |
| 9 | 自動購入NFT | type='auto_buy', cycle_id記録 |

---

**Document Owner:** @HashPilot Dev Team  
**Last Updated:** 2025-07-07  
**Status:** NFT区別機能（2タイプのみ）- 実装準備完了
