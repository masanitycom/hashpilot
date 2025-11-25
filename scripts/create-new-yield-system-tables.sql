-- ========================================
-- 新日利システムのテーブル設計（累積ベース）
-- ========================================

-- 1. daily_yield_log_v2: 新しい日利ログ（金額ベース）
CREATE TABLE IF NOT EXISTS daily_yield_log_v2 (
  id BIGSERIAL PRIMARY KEY,
  date DATE NOT NULL UNIQUE,

  -- 入力データ
  total_profit_amount NUMERIC(15, 2) NOT NULL,  -- 全体運用利益（管理者入力）
  total_nft_count INTEGER NOT NULL,              -- 当日の全NFT数
  profit_per_nft NUMERIC(15, 2) NOT NULL,        -- 1 NFTあたりの利益（計算値）

  -- 累積計算（手数料控除前）
  cumulative_gross_profit NUMERIC(15, 2) NOT NULL,  -- G_d: 累積利益（手数料前）

  -- 手数料計算
  fee_rate NUMERIC(5, 4) DEFAULT 0.30,           -- 手数料率（30%）
  cumulative_fee NUMERIC(15, 2) NOT NULL,        -- F_d: 手数料累積

  -- 顧客表示（手数料控除後）
  cumulative_net_profit NUMERIC(15, 2) NOT NULL, -- N_d: 顧客累積利益
  daily_pnl NUMERIC(15, 2) NOT NULL,             -- ΔN_d: 当日確定PNL

  -- 分配額（ΔN_dのプラス分のみ）
  distribution_dividend NUMERIC(15, 2) DEFAULT 0,   -- 配当: 60%
  distribution_affiliate NUMERIC(15, 2) DEFAULT 0,  -- アフィリ: 30%
  distribution_stock NUMERIC(15, 2) DEFAULT 0,      -- ストック: 10%

  -- メタデータ
  is_month_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT,
  notes TEXT
);

-- インデックス
CREATE INDEX idx_daily_yield_log_v2_date ON daily_yield_log_v2(date);

-- 2. user_monthly_summary: ユーザーごとの月次サマリー
CREATE TABLE IF NOT EXISTS user_monthly_summary (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  year_month TEXT NOT NULL,  -- 'YYYY-MM'形式

  -- 月間累積（手数料控除前）
  monthly_gross_profit NUMERIC(15, 2) DEFAULT 0,

  -- 月間累積（手数料控除後）
  monthly_net_profit NUMERIC(15, 2) DEFAULT 0,

  -- 月間手数料
  monthly_fee NUMERIC(15, 2) DEFAULT 0,

  -- 分配済み
  received_dividend NUMERIC(15, 2) DEFAULT 0,
  received_affiliate NUMERIC(15, 2) DEFAULT 0,
  received_stock NUMERIC(15, 2) DEFAULT 0,

  -- NFT情報
  avg_nft_count NUMERIC(10, 2),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, year_month)
);

CREATE INDEX idx_user_monthly_summary_user_month ON user_monthly_summary(user_id, year_month);

-- 3. stock_fund: ストック資金管理
CREATE TABLE IF NOT EXISTS stock_fund (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  date DATE NOT NULL,

  -- ストック資金
  stock_amount NUMERIC(15, 2) NOT NULL,  -- 当日のストック加算額
  cumulative_stock NUMERIC(15, 2) NOT NULL,  -- ストック累積

  -- メタデータ
  source TEXT DEFAULT 'daily_distribution',  -- 'daily_distribution', 'manual_adjustment'
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, date, source)
);

CREATE INDEX idx_stock_fund_user_date ON stock_fund(user_id, date);

-- 4. daily_yield_calculation_log: 計算ログ（デバッグ用）
CREATE TABLE IF NOT EXISTS daily_yield_calculation_log (
  id BIGSERIAL PRIMARY KEY,
  date DATE NOT NULL,
  calculation_step TEXT NOT NULL,  -- 'input', 'per_nft', 'cumulative', 'distribution'

  -- 計算値の記録
  input_values JSONB,
  calculated_values JSONB,
  validation_result JSONB,

  -- エラー記録
  has_error BOOLEAN DEFAULT FALSE,
  error_message TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_daily_yield_calc_log_date ON daily_yield_calculation_log(date);

-- ========================================
-- コメント追加
-- ========================================

COMMENT ON TABLE daily_yield_log_v2 IS '新日利システム: 累積ベースの日利ログ（金額入力方式）';
COMMENT ON COLUMN daily_yield_log_v2.total_profit_amount IS '全体運用利益（管理者が金額で入力）';
COMMENT ON COLUMN daily_yield_log_v2.profit_per_nft IS '1 NFTあたりの利益 = total_profit_amount / total_nft_count';
COMMENT ON COLUMN daily_yield_log_v2.cumulative_gross_profit IS 'G_d: 累積利益（手数料控除前）';
COMMENT ON COLUMN daily_yield_log_v2.cumulative_fee IS 'F_d: 手数料累積 = 0.30 × max(G_d, 0)';
COMMENT ON COLUMN daily_yield_log_v2.cumulative_net_profit IS 'N_d: 顧客累積利益 = G_d - F_d';
COMMENT ON COLUMN daily_yield_log_v2.daily_pnl IS 'ΔN_d: 当日確定PNL = N_d - N_{d-1}';
COMMENT ON COLUMN daily_yield_log_v2.distribution_dividend IS '配当分配額 = 0.60 × max(ΔN_d, 0)';
COMMENT ON COLUMN daily_yield_log_v2.distribution_affiliate IS 'アフィリエイト分配額 = 0.30 × max(ΔN_d, 0)';
COMMENT ON COLUMN daily_yield_log_v2.distribution_stock IS 'ストック分配額 = 0.10 × max(ΔN_d, 0)';

COMMENT ON TABLE user_monthly_summary IS 'ユーザーごとの月次サマリー（整合性確認用）';
COMMENT ON TABLE stock_fund IS 'ストック資金管理（10%の未配当分）';
COMMENT ON TABLE daily_yield_calculation_log IS '日利計算ログ（デバッグ・監査用）';

-- ========================================
-- 成功メッセージ
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '✅ 新日利システムのテーブルを作成しました';
  RAISE NOTICE '';
  RAISE NOTICE '作成されたテーブル:';
  RAISE NOTICE '  1. daily_yield_log_v2 - 累積ベースの日利ログ';
  RAISE NOTICE '  2. user_monthly_summary - ユーザー月次サマリー';
  RAISE NOTICE '  3. stock_fund - ストック資金管理';
  RAISE NOTICE '  4. daily_yield_calculation_log - 計算ログ';
END $$;
