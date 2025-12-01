-- ========================================
-- データベーステーブル構造確認
-- ========================================

-- 全テーブル一覧を取得
SELECT 
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- user_daily_profitテーブルの構造
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'user_daily_profit'
ORDER BY ordinal_position;

-- affiliate_cycleテーブルの構造
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'affiliate_cycle'
ORDER BY ordinal_position;

-- user_referral_profit_monthlyテーブルの構造
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'user_referral_profit_monthly'
ORDER BY ordinal_position;

