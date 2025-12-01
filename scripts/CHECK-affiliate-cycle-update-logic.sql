-- ========================================
-- affiliate_cycleの更新ロジック確認
-- ========================================

-- 11月15日運用開始ユーザー（available_usdtが低いユーザー）の詳細
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    
    -- 11月の個人日利（user_daily_profitから）
    COALESCE(SUM(udp.daily_profit), 0) as total_daily_profit_nov,
    
    -- 11月の紹介報酬（user_referral_profit_monthlyから）
    COALESCE(referral.nov_referral, 0) as total_referral_profit_nov,
    
    -- 合計（期待値）
    COALESCE(SUM(udp.daily_profit), 0) + COALESCE(referral.nov_referral, 0) as expected_total,
    
    -- affiliate_cycleの実際の値
    ac.available_usdt as actual_available_usdt,
    ac.cum_usdt as actual_cum_usdt,
    
    -- 差額
    ac.available_usdt - (COALESCE(SUM(udp.daily_profit), 0) + COALESCE(referral.nov_referral, 0)) as difference
    
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as nov_referral
    FROM user_referral_profit_monthly
    WHERE year = 2025 AND month = 11
    GROUP BY user_id
) referral ON u.user_id = referral.user_id
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.operation_start_date, referral.nov_referral, ac.available_usdt, ac.cum_usdt
ORDER BY difference ASC
LIMIT 20;

-- cum_usdtの計算確認（紹介報酬のみのはず）
SELECT 
    u.user_id,
    u.email,
    ac.cum_usdt as actual_cum_usdt,
    COALESCE(SUM(urpm.profit_amount), 0) as referral_total_all_time,
    ac.cum_usdt - COALESCE(SUM(urpm.profit_amount), 0) as cum_usdt_difference
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_referral_profit_monthly urpm ON u.user_id = urpm.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, ac.cum_usdt
ORDER BY u.user_id
LIMIT 20;

-- available_usdtの計算方法を確認（RPC関数の結果）
-- 個人日利は60%配分、紹介報酬は100%配分のはず
SELECT 
    '個人日利は60%配分されているか確認' as check_type,
    u.user_id,
    SUM(udp.daily_profit) as total_daily_profit,
    SUM(udp.daily_profit) * 0.6 as expected_60_percent,
    ac.available_usdt,
    ac.cum_usdt
FROM users u
INNER JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-15' 
    AND udp.date <= '2025-11-30'
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
    AND ac.cum_usdt = 0  -- 紹介報酬なしのユーザーのみ
GROUP BY u.user_id, ac.available_usdt, ac.cum_usdt
LIMIT 10;

