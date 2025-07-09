-- Phase 3: 日利システムのテスト

-- 1. テスト用日利投稿（2025年1月8日、日利1%、マージン30%）
SELECT admin_post_yield(
    '2025-01-08'::DATE,
    0.0100::DECIMAL(5,4),  -- 1%日利
    0.30::DECIMAL(3,2),    -- 30%マージン
    FALSE
);

-- 2. 結果確認
SELECT 'daily_yield_log' as table_name, to_jsonb(d) as data FROM daily_yield_log d WHERE date = '2025-01-08'
UNION ALL
SELECT 'user_daily_profit' as table_name, to_jsonb(u) as data FROM user_daily_profit u WHERE date = '2025-01-08' LIMIT 5
UNION ALL
SELECT 'company_daily_profit' as table_name, to_jsonb(c) as data FROM company_daily_profit c WHERE date = '2025-01-08'
UNION ALL
SELECT 'affiliate_reward' as table_name, to_jsonb(a) as data FROM affiliate_reward a WHERE date = '2025-01-08' LIMIT 5;
