-- 🚨 緊急修正: 全ユーザーの利益計算を修正
-- 2025年1月16日 緊急対応

BEGIN;

-- 1. 現在の異常状況確認
SELECT 
    '=== 修正前の状況 ===' as status,
    COUNT(*) as total_users,
    COUNT(CASE WHEN ac.total_nft_count > 0 THEN 1 END) as users_with_nft,
    COUNT(CASE WHEN udp.user_id IS NOT NULL THEN 1 END) as users_with_profit
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true;

-- 2. 全ユーザーのaffiliate_cycleを修正
-- 購入データから正しいNFT数を設定
WITH user_nft_counts AS (
    SELECT 
        u.user_id,
        COALESCE(SUM(p.nft_quantity), 0) as total_nft,
        MIN(p.admin_approved_at::date) as first_approval
    FROM users u
    LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
    WHERE u.has_approved_nft = true
    GROUP BY u.user_id
)
-- 既存のaffiliate_cycleを更新
UPDATE affiliate_cycle
SET 
    total_nft_count = unc.total_nft,
    manual_nft_count = unc.total_nft,
    updated_at = NOW()
FROM user_nft_counts unc
WHERE affiliate_cycle.user_id = unc.user_id
AND unc.total_nft > 0;

-- 3. affiliate_cycleレコードが存在しないユーザーのために新規作成
WITH user_nft_counts AS (
    SELECT 
        u.user_id,
        COALESCE(SUM(p.nft_quantity), 0) as total_nft,
        MIN(p.admin_approved_at::date) as first_approval
    FROM users u
    LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
    WHERE u.has_approved_nft = true
    GROUP BY u.user_id
    HAVING COALESCE(SUM(p.nft_quantity), 0) > 0
)
INSERT INTO affiliate_cycle (
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    available_usdt,
    auto_nft_count,
    manual_nft_count,
    cycle_number,
    next_action,
    cycle_start_date,
    created_at,
    updated_at
)
SELECT 
    unc.user_id,
    'USDT',
    unc.total_nft,
    0,
    0,
    0,
    unc.total_nft,
    1,
    'usdt',
    unc.first_approval,
    NOW(),
    NOW()
FROM user_nft_counts unc
WHERE NOT EXISTS (
    SELECT 1 FROM affiliate_cycle ac WHERE ac.user_id = unc.user_id
);

-- 4. 全ユーザーの過去利益を計算
-- 日利設定データを一時テーブルに格納
CREATE TEMP TABLE temp_daily_rates AS
SELECT 
    date,
    COALESCE(yield_rate, 0.016) as yield_rate,
    COALESCE(margin_rate, 30) as margin_rate,
    COALESCE(user_rate, ((0.016 * (100 - 30) / 100) * 0.6)) as user_rate
FROM daily_yield_log
WHERE date >= '2025-07-02'
UNION ALL
-- デフォルト値で埋める
SELECT 
    generate_series(
        '2025-07-02'::date,
        CURRENT_DATE - 1,
        '1 day'::interval
    )::date as date,
    0.016 as yield_rate,
    30 as margin_rate,
    ((0.016 * (100 - 30) / 100) * 0.6) as user_rate
WHERE NOT EXISTS (
    SELECT 1 FROM daily_yield_log dyl 
    WHERE dyl.date = generate_series(
        '2025-07-02'::date,
        CURRENT_DATE - 1,
        '1 day'::interval
    )::date
);

-- 5. 各ユーザーの利益を計算して挿入
WITH user_operation_dates AS (
    SELECT 
        u.user_id,
        ac.total_nft_count,
        MIN(p.admin_approved_at::date) + INTERVAL '15 days' as operation_start
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
    WHERE u.has_approved_nft = true
    AND ac.total_nft_count > 0
    GROUP BY u.user_id, ac.total_nft_count
),
profit_calculations AS (
    SELECT 
        uod.user_id,
        dr.date,
        (uod.total_nft_count * 1000 * dr.user_rate / 100) as daily_profit,
        dr.yield_rate,
        dr.user_rate,
        (uod.total_nft_count * 1000) as base_amount,
        'USDT' as phase
    FROM user_operation_dates uod
    CROSS JOIN temp_daily_rates dr
    WHERE dr.date >= uod.operation_start::date
    AND dr.date < CURRENT_DATE
    AND NOT EXISTS (
        -- 既存の利益記録がある日はスキップ
        SELECT 1 FROM user_daily_profit udp 
        WHERE udp.user_id = uod.user_id 
        AND udp.date = dr.date
    )
)
INSERT INTO user_daily_profit (
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
)
SELECT 
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    NOW()
FROM profit_calculations;

-- 6. affiliate_cycleの累積利益を更新
UPDATE affiliate_cycle
SET 
    cum_usdt = (
        SELECT COALESCE(SUM(udp.daily_profit), 0)
        FROM user_daily_profit udp
        WHERE udp.user_id = affiliate_cycle.user_id
    ),
    available_usdt = (
        SELECT COALESCE(SUM(udp.daily_profit), 0)
        FROM user_daily_profit udp
        WHERE udp.user_id = affiliate_cycle.user_id
    ),
    updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM users u 
    WHERE u.user_id = affiliate_cycle.user_id 
    AND u.has_approved_nft = true
);

-- 7. 修正後の確認
SELECT 
    '=== 修正後の状況 ===' as status,
    COUNT(*) as total_users,
    COUNT(CASE WHEN ac.total_nft_count > 0 THEN 1 END) as users_with_nft,
    COUNT(CASE WHEN udp.user_id IS NOT NULL THEN 1 END) as users_with_profit,
    COALESCE(SUM(ac.cum_usdt), 0) as total_profits
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true;

-- 8. ユーザー別の利益確認（上位10名）
SELECT 
    '=== 修正後の上位10ユーザー ===' as check_type,
    u.user_id,
    u.email,
    ac.total_nft_count,
    ac.cum_usdt,
    COUNT(udp.date) as profit_days
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true
AND ac.total_nft_count > 0
GROUP BY u.user_id, u.email, ac.total_nft_count, ac.cum_usdt
ORDER BY ac.cum_usdt DESC
LIMIT 10;

-- 9. 緊急修正ログ
SELECT log_system_event(
    'SUCCESS',
    'EMERGENCY_PROFIT_FIX',
    NULL,
    '全ユーザーの利益計算を緊急修正',
    jsonb_build_object(
        'action', 'fixed_all_user_profits',
        'timestamp', NOW(),
        'severity', 'CRITICAL'
    )
);

-- 一時テーブル削除
DROP TABLE temp_daily_rates;

COMMIT;

-- 最終確認
SELECT 
    '=== 最終確認: 利益が0のユーザー ===' as final_check,
    u.user_id,
    u.email,
    ac.total_nft_count,
    ac.cum_usdt,
    CASE 
        WHEN ac.total_nft_count > 0 AND ac.cum_usdt = 0 THEN '要確認'
        ELSE '正常'
    END as status
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true
AND ac.total_nft_count > 0
AND ac.cum_usdt = 0;