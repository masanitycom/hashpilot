-- ========================================
-- 11月の紹介報酬データ確認
-- ========================================

-- user_referral_profitテーブルの11月データ
SELECT
    COUNT(*) as total_records,
    SUM(profit_amount) as total_amount,
    COUNT(DISTINCT user_id) as parent_users,
    COUNT(DISTINCT child_user_id) as child_users,
    MIN(date) as min_date,
    MAX(date) as max_date
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

-- レベル別集計
SELECT
    referral_level,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
GROUP BY referral_level
ORDER BY referral_level;
