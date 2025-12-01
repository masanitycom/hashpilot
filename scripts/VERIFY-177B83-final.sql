-- ========================================
-- ユーザー177B83の最終検証
-- ========================================

-- 11月の紹介報酬（月次計算）
SELECT
    referral_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT child_user_id) as unique_children,
    SUM(child_monthly_profit) as total_child_profit,
    SUM(profit_amount) as total_referral_profit
FROM user_referral_profit_monthly
WHERE user_id = '177B83'
    AND year = 2025
    AND month = 11
GROUP BY referral_level
ORDER BY referral_level;

-- 合計
SELECT
    SUM(profit_amount) as total_referral_profit_november
FROM user_referral_profit_monthly
WHERE user_id = '177B83'
    AND year = 2025
    AND month = 11;

-- 個人利益
SELECT
    SUM(daily_profit) as personal_profit_november
FROM user_daily_profit
WHERE user_id = '177B83'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30';
