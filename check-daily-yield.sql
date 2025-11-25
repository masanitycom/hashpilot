-- 日利設定の確認
SELECT * FROM daily_yield_log ORDER BY date DESC LIMIT 10;

-- ユーザー日利データの確認
SELECT COUNT(*) as user_profit_count FROM user_daily_profit;

-- 紹介報酬データの確認  
SELECT COUNT(*) as referral_profit_count FROM user_referral_profit;
