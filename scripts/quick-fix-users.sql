-- 🚨 簡単修正: 全ユーザーの利益計算
-- 2025年1月16日 緊急対応（簡易版）

-- 1. 全ユーザーのaffiliate_cycleのNFT数を修正
UPDATE affiliate_cycle 
SET total_nft_count = (
    SELECT COALESCE(SUM(nft_quantity), 0)
    FROM purchases p
    WHERE p.user_id = affiliate_cycle.user_id 
    AND p.admin_approved = true
),
manual_nft_count = (
    SELECT COALESCE(SUM(nft_quantity), 0)
    FROM purchases p
    WHERE p.user_id = affiliate_cycle.user_id 
    AND p.admin_approved = true
),
updated_at = NOW()
WHERE user_id IN (
    SELECT user_id FROM users WHERE has_approved_nft = true
);

-- 2. affiliate_cycleレコードがないユーザーに作成
INSERT INTO affiliate_cycle (
    user_id, phase, total_nft_count, cum_usdt, available_usdt,
    auto_nft_count, manual_nft_count, cycle_number, next_action,
    cycle_start_date, created_at, updated_at
)
SELECT 
    u.user_id,
    'USDT',
    COALESCE(SUM(p.nft_quantity), 0),
    0, 0, 0,
    COALESCE(SUM(p.nft_quantity), 0),
    1, 'usdt',
    MIN(p.admin_approved_at),
    NOW(), NOW()
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.has_approved_nft = true
AND NOT EXISTS (SELECT 1 FROM affiliate_cycle ac WHERE ac.user_id = u.user_id)
GROUP BY u.user_id
HAVING COALESCE(SUM(p.nft_quantity), 0) > 0;

-- 3. 過去の利益を計算（7/2から今日まで）
INSERT INTO user_daily_profit (user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at)
SELECT 
    ac.user_id,
    d.date,
    (ac.total_nft_count * 1000 * 0.0067) as daily_profit,
    0.016 as yield_rate,
    0.0067 as user_rate,
    (ac.total_nft_count * 1000) as base_amount,
    'USDT' as phase,
    NOW()
FROM affiliate_cycle ac
CROSS JOIN LATERAL (
    SELECT generate_series(
        GREATEST('2025-07-02'::date, 
                 COALESCE((SELECT MIN(admin_approved_at::date) + 15 FROM purchases WHERE user_id = ac.user_id AND admin_approved = true), '2025-07-02'::date)),
        CURRENT_DATE - 1,
        '1 day'::interval
    )::date as date
) d
WHERE ac.total_nft_count > 0
AND NOT EXISTS (
    SELECT 1 FROM user_daily_profit udp 
    WHERE udp.user_id = ac.user_id AND udp.date = d.date
);

-- 4. 累積利益を更新
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
updated_at = NOW();

-- 5. 結果確認
SELECT 
    '修正完了' as status,
    COUNT(*) as total_users,
    COUNT(CASE WHEN total_nft_count > 0 THEN 1 END) as users_with_nft,
    COUNT(CASE WHEN cum_usdt > 0 THEN 1 END) as users_with_profit,
    SUM(cum_usdt) as total_profit
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true;