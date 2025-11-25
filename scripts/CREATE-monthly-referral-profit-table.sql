-- ========================================
-- 月次紹介報酬テーブルの作成
-- ========================================
-- 作成日: 2025-11-23
--
-- 仕様変更: 紹介報酬を日次計算から月次計算に変更
-- - 日次では個人利益のみ配布
-- - 月末に紹介報酬をまとめて計算
-- - ユーザーは月別の利益履歴を確認可能
-- ========================================

-- ============================================
-- monthly_referral_profit テーブル作成
-- ============================================

CREATE TABLE IF NOT EXISTS monthly_referral_profit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,                  -- 報酬を受け取るユーザー
    year_month TEXT NOT NULL,               -- 'YYYY-MM' 形式（例: '2025-11'）
    referral_level INTEGER NOT NULL,        -- レベル (1, 2, 3)
    child_user_id TEXT NOT NULL,            -- 報酬発生元（下位ユーザー）
    profit_amount DECIMAL(10,3) NOT NULL,   -- 報酬額（ドル）
    calculation_date DATE NOT NULL,         -- 計算実行日（通常は月末翌日）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CHECK (referral_level IN (1, 2, 3)),
    CHECK (profit_amount >= 0),
    CHECK (year_month ~ '^\d{4}-\d{2}$')    -- YYYY-MM形式のチェック
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_monthly_referral_user_month
ON monthly_referral_profit(user_id, year_month);

CREATE INDEX IF NOT EXISTS idx_monthly_referral_month
ON monthly_referral_profit(year_month);

CREATE INDEX IF NOT EXISTS idx_monthly_referral_child
ON monthly_referral_profit(child_user_id);

-- ユニーク制約（同じ月・同じレベル・同じ子ユーザーからの報酬は1つだけ）
CREATE UNIQUE INDEX IF NOT EXISTS idx_monthly_referral_unique
ON monthly_referral_profit(user_id, year_month, referral_level, child_user_id);

-- ============================================
-- ビュー: 月別紹介報酬サマリー
-- ============================================

CREATE OR REPLACE VIEW monthly_referral_profit_summary AS
SELECT
    user_id,
    year_month,
    SUM(profit_amount) as total_referral_profit,
    SUM(CASE WHEN referral_level = 1 THEN profit_amount ELSE 0 END) as level1_profit,
    SUM(CASE WHEN referral_level = 2 THEN profit_amount ELSE 0 END) as level2_profit,
    SUM(CASE WHEN referral_level = 3 THEN profit_amount ELSE 0 END) as level3_profit,
    COUNT(DISTINCT child_user_id) as unique_children,
    MAX(calculation_date) as calculation_date
FROM monthly_referral_profit
GROUP BY user_id, year_month;

-- ============================================
-- ビュー: ユーザー別月次利益（個人+紹介）
-- ============================================

CREATE OR REPLACE VIEW user_monthly_profit_combined AS
WITH personal_profit AS (
    SELECT
        user_id,
        TO_CHAR(date, 'YYYY-MM') as year_month,
        SUM(daily_profit) as total_personal_profit
    FROM nft_daily_profit
    GROUP BY user_id, TO_CHAR(date, 'YYYY-MM')
),
referral_profit AS (
    SELECT
        user_id,
        year_month,
        total_referral_profit
    FROM monthly_referral_profit_summary
)
SELECT
    COALESCE(pp.user_id, rp.user_id) as user_id,
    COALESCE(pp.year_month, rp.year_month) as year_month,
    COALESCE(pp.total_personal_profit, 0) as personal_profit,
    COALESCE(rp.total_referral_profit, 0) as referral_profit,
    COALESCE(pp.total_personal_profit, 0) + COALESCE(rp.total_referral_profit, 0) as total_profit
FROM personal_profit pp
FULL OUTER JOIN referral_profit rp
    ON pp.user_id = rp.user_id AND pp.year_month = rp.year_month
ORDER BY year_month DESC, user_id;

-- ============================================
-- RPC: ユーザーの月別利益履歴を取得
-- ============================================

CREATE OR REPLACE FUNCTION get_user_monthly_profit_history(
    p_user_id TEXT,
    p_year_month TEXT DEFAULT NULL  -- NULL = 全期間、'YYYY-MM' = 指定月のみ
)
RETURNS TABLE(
    year_month TEXT,
    personal_profit DECIMAL(10,3),
    referral_profit DECIMAL(10,3),
    total_profit DECIMAL(10,3)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ump.year_month,
        ump.personal_profit,
        ump.referral_profit,
        ump.total_profit
    FROM user_monthly_profit_combined ump
    WHERE ump.user_id = p_user_id
        AND (p_year_month IS NULL OR ump.year_month = p_year_month)
    ORDER BY ump.year_month DESC;
END;
$$;

-- ============================================
-- RPC: 前月の確定報酬を取得
-- ============================================

CREATE OR REPLACE FUNCTION get_last_month_profit(
    p_user_id TEXT
)
RETURNS TABLE(
    year_month TEXT,
    personal_profit DECIMAL(10,3),
    referral_profit DECIMAL(10,3),
    total_profit DECIMAL(10,3)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_month TEXT;
BEGIN
    -- 先月を計算 (YYYY-MM形式)
    v_last_month := TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYY-MM');

    RETURN QUERY
    SELECT
        ump.year_month,
        ump.personal_profit,
        ump.referral_profit,
        ump.total_profit
    FROM user_monthly_profit_combined ump
    WHERE ump.user_id = p_user_id
        AND ump.year_month = v_last_month;
END;
$$;

-- ============================================
-- RPC: 利用可能な月一覧を取得
-- ============================================

CREATE OR REPLACE FUNCTION get_available_months(
    p_user_id TEXT
)
RETURNS TABLE(
    year_month TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ump.year_month
    FROM user_monthly_profit_combined ump
    WHERE ump.user_id = p_user_id
    ORDER BY ump.year_month DESC;
END;
$$;

-- ============================================
-- コメント
-- ============================================

COMMENT ON TABLE monthly_referral_profit IS '月次紹介報酬の記録（月末にまとめて計算）';
COMMENT ON COLUMN monthly_referral_profit.user_id IS '報酬を受け取るユーザーID';
COMMENT ON COLUMN monthly_referral_profit.year_month IS '対象年月（YYYY-MM形式）';
COMMENT ON COLUMN monthly_referral_profit.child_user_id IS '報酬発生元（下位ユーザー）のID';
COMMENT ON COLUMN monthly_referral_profit.referral_level IS '紹介レベル (1=直接, 2=間接1, 3=間接2)';
COMMENT ON COLUMN monthly_referral_profit.profit_amount IS '報酬額（ドル）';
COMMENT ON COLUMN monthly_referral_profit.calculation_date IS '計算実行日（通常は月末翌日）';

COMMENT ON VIEW monthly_referral_profit_summary IS 'ユーザーの月次紹介報酬サマリー';
COMMENT ON VIEW user_monthly_profit_combined IS 'ユーザーの月別利益（個人+紹介）';

COMMENT ON FUNCTION get_user_monthly_profit_history IS 'ユーザーの月別利益履歴を取得（検索機能付き）';
COMMENT ON FUNCTION get_last_month_profit IS '前月の確定報酬を取得';
COMMENT ON FUNCTION get_available_months IS 'ユーザーのデータがある月一覧を取得';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ 月次紹介報酬テーブルを作成しました';
    RAISE NOTICE '============================================';
    RAISE NOTICE '📋 作成されたオブジェクト:';
    RAISE NOTICE '   - monthly_referral_profit テーブル';
    RAISE NOTICE '   - monthly_referral_profit_summary ビュー';
    RAISE NOTICE '   - user_monthly_profit_combined ビュー';
    RAISE NOTICE '   - get_user_monthly_profit_history() RPC関数';
    RAISE NOTICE '   - get_last_month_profit() RPC関数';
    RAISE NOTICE '   - get_available_months() RPC関数';
    RAISE NOTICE '';
    RAISE NOTICE '📊 テーブル構造:';
    RAISE NOTICE '   - user_id: 報酬受取ユーザー';
    RAISE NOTICE '   - year_month: YYYY-MM形式';
    RAISE NOTICE '   - referral_level: 1, 2, 3';
    RAISE NOTICE '   - child_user_id: 報酬発生元';
    RAISE NOTICE '   - profit_amount: 報酬額';
    RAISE NOTICE '';
    RAISE NOTICE '✅ 次のステップ:';
    RAISE NOTICE '   1. CREATE-process-monthly-referral-profit.sql を実行';
    RAISE NOTICE '   2. FIX-process-daily-yield-v2-remove-referral.sql を実行';
    RAISE NOTICE '   3. フロントエンドを修正';
    RAISE NOTICE '============================================';
END $$;
