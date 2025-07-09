-- Phase 3: 日利システムのテスト

-- 1. テスト用日利投稿（2025年1月8日、日利1%、マージン30%）
SELECT admin_post_yield(
    '2025-01-08'::DATE,
    0.0100::DECIMAL(5,4),  -- 1%日利
    0.30::DECIMAL(3,2),    -- 30%マージン
    FALSE
);

-- 2. 結果確認
SELECT 'daily_yield_log' as table_name, date, yield_rate, margin_rate, total_users, total_profit 
FROM daily_yield_log 
WHERE date = '2025-01-08';

SELECT 'user_daily_profit' as table_name, user_id, date, investment_amount, profit_amount 
FROM user_daily_profit 
WHERE date = '2025-01-08' 
LIMIT 5;

SELECT 'company_daily_profit' as table_name, date, total_margin, total_company_profit 
FROM company_daily_profit 
WHERE date = '2025-01-08';

SELECT 'affiliate_reward' as table_name, user_id, date, reward_amount, level 
FROM affiliate_reward 
WHERE date = '2025-01-08' 
LIMIT 5;
