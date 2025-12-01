-- 11月15日運用開始ユーザーのnft_daily_profitを確認
SELECT
    ndp.user_id,
    ndp.date,
    ndp.nft_id,
    ndp.daily_profit,
    u.operation_start_date
FROM nft_daily_profit ndp
INNER JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND ndp.date >= '2025-11-15'
    AND ndp.date <= '2025-11-30'
    AND u.user_id IN (
        SELECT user_id 
        FROM users 
        WHERE operation_start_date = '2025-11-15'
            AND has_approved_nft = true
        ORDER BY user_id
        LIMIT 3
    )
ORDER BY ndp.user_id, ndp.date;

-- user_daily_profitとの比較（同じユーザー）
SELECT 
    u.user_id,
    u.operation_start_date,
    
    -- nft_daily_profitの合計
    COALESCE(SUM(ndp.daily_profit), 0) as nft_daily_profit_total,
    
    -- user_daily_profitの合計（VIEWから）
    COALESCE(SUM(udp.daily_profit), 0) as user_daily_profit_total,
    
    -- affiliate_cycleのavailable_usdt
    ac.available_usdt
    
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id 
    AND ndp.date >= '2025-11-15' 
    AND ndp.date <= '2025-11-30'
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-15' 
    AND udp.date <= '2025-11-30'
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
    AND ac.cum_usdt = 0  -- 紹介報酬なしのユーザーのみ
GROUP BY u.user_id, u.operation_start_date, ac.available_usdt
ORDER BY u.user_id
LIMIT 10;

