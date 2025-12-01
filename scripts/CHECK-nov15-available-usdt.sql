-- ========================================
-- 11月15日運用開始ユーザーのavailable_usdt詳細調査
-- ========================================

-- サンプル3名の詳細
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    
    -- 11月の個人日利
    COALESCE(personal.nov_profit, 0) as nov_personal_profit,
    
    -- 11月の紹介報酬
    COALESCE(referral.nov_referral, 0) as nov_referral_profit,
    
    -- 期待値（11月のみ）
    COALESCE(personal.nov_profit, 0) + COALESCE(referral.nov_referral, 0) as expected_nov_only,
    
    -- 実際のavailable_usdt
    ac.available_usdt,
    
    -- 差額
    ac.available_usdt - (COALESCE(personal.nov_profit, 0) + COALESCE(referral.nov_referral, 0)) as difference,
    
    -- affiliate_cycleの詳細
    ac.cum_usdt,
    ac.phase,
    ac.auto_nft_count,
    ac.manual_nft_count
FROM users u
LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as nov_profit
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    GROUP BY user_id
) personal ON u.user_id = personal.user_id
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as nov_referral
    FROM user_referral_profit_monthly
    WHERE year = 2025 AND month = 11
    GROUP BY user_id
) referral ON u.user_id = referral.user_id
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
ORDER BY u.user_id
LIMIT 10;

-- 10月以前の日利履歴があるか確認
SELECT 
    u.user_id,
    u.email,
    COUNT(*) as records_before_nov,
    SUM(udp.daily_profit) as total_profit_before_nov
FROM users u
INNER JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND udp.date < '2025-11-01'
GROUP BY u.user_id, u.email;

