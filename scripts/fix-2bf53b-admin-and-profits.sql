-- 2BF53Bの管理者登録とNFT数修正、利益計算
-- 2025年1月16日 緊急修正

BEGIN;

-- 1. 現在の状況確認
SELECT 
    '=== 修正前の状況確認 ===' as step,
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.total_nft_count,
    ac.cum_usdt,
    p.nft_quantity as purchased_nft,
    p.admin_approved_at,
    a.role as admin_role
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN admins a ON u.user_id = a.user_id
WHERE u.user_id = '2BF53B';

-- 2. adminsテーブルに2BF53Bを追加（既に存在する場合はスキップ）
INSERT INTO admins (user_id, role, created_at)
VALUES ('2BF53B', 'admin', NOW())
ON CONFLICT (user_id) DO NOTHING;

-- 3. affiliate_cycleのNFT数を修正
-- まず、購入済みNFT数を確認
WITH nft_count AS (
    SELECT 
        user_id,
        SUM(nft_quantity) as total_nft
    FROM purchases
    WHERE user_id = '2BF53B' 
    AND admin_approved = true
    GROUP BY user_id
)
UPDATE affiliate_cycle
SET 
    total_nft_count = nc.total_nft,
    manual_nft_count = nc.total_nft,
    updated_at = NOW()
FROM nft_count nc
WHERE affiliate_cycle.user_id = nc.user_id;

-- affiliate_cycleレコードが存在しない場合は作成
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
    '2BF53B',
    'USDT',
    SUM(nft_quantity),
    0,
    0,
    0,
    SUM(nft_quantity),
    1,
    'usdt',
    MIN(admin_approved_at::date),
    NOW(),
    NOW()
FROM purchases
WHERE user_id = '2BF53B' 
AND admin_approved = true
AND NOT EXISTS (
    SELECT 1 FROM affiliate_cycle WHERE user_id = '2BF53B'
);

-- 4. 過去の利益を計算して挿入
-- 運用開始日（承認日+15日）から今日までの利益を計算
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
WITH profit_dates AS (
    -- 運用開始日から今日までの日付を生成
    SELECT 
        '2BF53B' as user_id,
        generate_series(
            (SELECT MIN(admin_approved_at::date) + INTERVAL '15 days' FROM purchases WHERE user_id = '2BF53B' AND admin_approved = true),
            CURRENT_DATE - 1,
            '1 day'::interval
        )::date as profit_date
),
daily_rates AS (
    -- 各日の利率を取得（なければデフォルト値使用）
    SELECT 
        pd.user_id,
        pd.profit_date,
        COALESCE(dyl.yield_rate, 0.016) as yield_rate,
        COALESCE(dyl.margin_rate, 30) as margin_rate,
        COALESCE(dyl.user_rate, ((0.016 * (100 - 30) / 100) * 0.6)) as user_rate,
        ac.total_nft_count * 1000 as base_amount,
        ac.phase
    FROM profit_dates pd
    CROSS JOIN affiliate_cycle ac
    LEFT JOIN daily_yield_log dyl ON dyl.date = pd.profit_date
    WHERE ac.user_id = pd.user_id
)
SELECT 
    user_id,
    profit_date,
    base_amount * user_rate / 100 as daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    NOW()
FROM daily_rates
WHERE NOT EXISTS (
    -- 既存の利益記録がある日はスキップ
    SELECT 1 FROM user_daily_profit udp 
    WHERE udp.user_id = daily_rates.user_id 
    AND udp.date = daily_rates.profit_date
);

-- 5. affiliate_cycleの累積利益を更新
UPDATE affiliate_cycle
SET 
    cum_usdt = (
        SELECT COALESCE(SUM(daily_profit), 0)
        FROM user_daily_profit
        WHERE user_id = '2BF53B'
    ),
    available_usdt = (
        SELECT COALESCE(SUM(daily_profit), 0)
        FROM user_daily_profit
        WHERE user_id = '2BF53B'
    ),
    updated_at = NOW()
WHERE user_id = '2BF53B';

-- 6. 修正後の確認
SELECT 
    '=== 修正後の状況確認 ===' as step,
    u.user_id,
    u.email,
    u.has_approved_nft,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    a.role as admin_role,
    COUNT(udp.date) as profit_days,
    SUM(udp.daily_profit) as total_profit
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN admins a ON u.user_id = a.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.user_id = '2BF53B'
GROUP BY u.user_id, u.email, u.has_approved_nft, ac.total_nft_count, ac.cum_usdt, ac.available_usdt, a.role;

-- 7. ログ記録
SELECT log_system_event(
    'SUCCESS',
    'ADMIN_PROFIT_FIX',
    '2BF53B',
    '管理者2BF53Bの利益計算を修正',
    jsonb_build_object(
        'action', 'fixed_admin_and_profits',
        'nft_count_updated', true,
        'profits_calculated', true
    )
);

COMMIT;

-- 実行後の詳細確認
SELECT 
    '=== 日別利益の確認 ===' as check_type,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount
FROM user_daily_profit
WHERE user_id = '2BF53B'
ORDER BY date DESC
LIMIT 10;