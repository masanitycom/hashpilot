-- ユーザー紹介報酬テーブルの作成
-- 作成日: 2025年10月7日
--
-- 各ユーザーが受け取った紹介報酬を記録するテーブル

-- ============================================
-- user_referral_profit テーブル作成
-- ============================================

CREATE TABLE IF NOT EXISTS user_referral_profit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,                  -- 報酬を受け取るユーザー
    date DATE NOT NULL,                     -- 報酬発生日
    referral_level INTEGER NOT NULL,        -- レベル (1, 2, 3)
    child_user_id TEXT NOT NULL,            -- 報酬発生元（下位ユーザー）
    profit_amount DECIMAL(10,3) NOT NULL,   -- 報酬額
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CHECK (referral_level IN (1, 2, 3)),
    CHECK (profit_amount >= 0)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_user_referral_profit_user_date
ON user_referral_profit(user_id, date);

CREATE INDEX IF NOT EXISTS idx_user_referral_profit_date
ON user_referral_profit(date);

CREATE INDEX IF NOT EXISTS idx_user_referral_profit_child
ON user_referral_profit(child_user_id);

-- ユニーク制約（同じ日・同じレベル・同じ子ユーザーからの報酬は1つだけ）
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_referral_profit_unique
ON user_referral_profit(user_id, date, referral_level, child_user_id);

-- ============================================
-- ユーザー紹介報酬サマリービュー
-- ============================================

CREATE OR REPLACE VIEW user_referral_profit_summary AS
SELECT
    user_id,
    date,
    SUM(profit_amount) as total_referral_profit,
    SUM(CASE WHEN referral_level = 1 THEN profit_amount ELSE 0 END) as level1_profit,
    SUM(CASE WHEN referral_level = 2 THEN profit_amount ELSE 0 END) as level2_profit,
    SUM(CASE WHEN referral_level = 3 THEN profit_amount ELSE 0 END) as level3_profit,
    COUNT(DISTINCT child_user_id) as unique_children
FROM user_referral_profit
GROUP BY user_id, date;

-- ============================================
-- ユーザーの累計紹介報酬ビュー
-- ============================================

CREATE OR REPLACE VIEW user_total_referral_profit AS
SELECT
    user_id,
    SUM(profit_amount) as total_referral_profit,
    SUM(CASE WHEN referral_level = 1 THEN profit_amount ELSE 0 END) as total_level1_profit,
    SUM(CASE WHEN referral_level = 2 THEN profit_amount ELSE 0 END) as total_level2_profit,
    SUM(CASE WHEN referral_level = 3 THEN profit_amount ELSE 0 END) as total_level3_profit,
    COUNT(DISTINCT date) as days_with_referral,
    COUNT(DISTINCT child_user_id) as total_unique_children,
    MIN(date) as first_referral_date,
    MAX(date) as last_referral_date
FROM user_referral_profit
GROUP BY user_id;

-- ============================================
-- コメント
-- ============================================

COMMENT ON TABLE user_referral_profit IS 'ユーザーが受け取った紹介報酬の記録';
COMMENT ON COLUMN user_referral_profit.user_id IS '報酬を受け取るユーザーID';
COMMENT ON COLUMN user_referral_profit.child_user_id IS '報酬発生元（下位ユーザー）のID';
COMMENT ON COLUMN user_referral_profit.referral_level IS '紹介レベル (1=直接, 2=間接1, 3=間接2)';
COMMENT ON COLUMN user_referral_profit.profit_amount IS '報酬額（ドル）';

COMMENT ON VIEW user_referral_profit_summary IS 'ユーザーの日次紹介報酬サマリー';
COMMENT ON VIEW user_total_referral_profit IS 'ユーザーの累計紹介報酬';

-- 完了メッセージ
DO $$
DECLARE
    v_table_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = 'user_referral_profit'
    ) INTO v_table_exists;

    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ user_referral_profit テーブルを作成しました';
    RAISE NOTICE '============================================';
    RAISE NOTICE '📋 作成されたオブジェクト:';
    RAISE NOTICE '   - user_referral_profit テーブル';
    RAISE NOTICE '   - user_referral_profit_summary ビュー';
    RAISE NOTICE '   - user_total_referral_profit ビュー';
    RAISE NOTICE '   - インデックス (user_date, date, child, unique)';
    RAISE NOTICE '';
    RAISE NOTICE '📊 テーブル構造:';
    RAISE NOTICE '   - user_id: 報酬受取ユーザー';
    RAISE NOTICE '   - date: 報酬発生日';
    RAISE NOTICE '   - referral_level: 1, 2, 3';
    RAISE NOTICE '   - child_user_id: 報酬発生元';
    RAISE NOTICE '   - profit_amount: 報酬額';
    RAISE NOTICE '';
    RAISE NOTICE '✅ 次のステップ:';
    RAISE NOTICE '   - update-referral-calculation-for-dormant.sql を再実行してください';
    RAISE NOTICE '============================================';
END $$;
