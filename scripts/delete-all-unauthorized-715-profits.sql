-- 🚨 7/15の全不正利益を削除
-- 2025年1月16日 緊急修正

-- 1. 7/15の全利益を削除（設定なし日のため）
DELETE FROM user_daily_profit 
WHERE date = '2025-07-15';

-- 2. 影響を受けたユーザーの累積利益を再計算
UPDATE affiliate_cycle 
SET cum_usdt = (
    SELECT COALESCE(SUM(daily_profit), 0)
    FROM user_daily_profit 
    WHERE user_id = affiliate_cycle.user_id
),
available_usdt = (
    SELECT COALESCE(SUM(daily_profit), 0)
    FROM user_daily_profit 
    WHERE user_id = affiliate_cycle.user_id
),
updated_at = NOW()
WHERE user_id IN ('6E1304', '794682', 'OOCJ16', 'Y9FVT1', '2BF53B');

-- 3. 削除確認
SELECT 
    '=== 削除確認 ===' as check_type,
    COUNT(*) as remaining_715_profits
FROM user_daily_profit 
WHERE date = '2025-07-15';

-- 4. 修正後の各ユーザー状況
SELECT 
    '=== 修正後の状況 ===' as check_type,
    ac.user_id,
    u.email,
    ac.cum_usdt,
    ac.available_usdt,
    COUNT(udp.date) as profit_days
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN user_daily_profit udp ON ac.user_id = udp.user_id
WHERE ac.user_id IN ('6E1304', '794682', 'OOCJ16', 'Y9FVT1', '2BF53B')
GROUP BY ac.user_id, u.email, ac.cum_usdt, ac.available_usdt
ORDER BY ac.cum_usdt DESC;