-- 🔍 紹介報酬システムの問題調査
-- 2025年7月17日 - 実際の動作確認

-- 1. 7A9637のLevel2紹介者B43A3Dの状況確認
SELECT 
    'B43A3D基本情報' as check_type,
    user_id,
    email,
    referrer_user_id,
    is_active,
    has_approved_nft,
    created_at
FROM users 
WHERE user_id = 'B43A3D';

-- 2. B43A3Dの購入・承認状況確認
SELECT 
    'B43A3D購入状況' as check_type,
    user_id,
    nft_quantity,
    amount_usd,
    admin_approved,
    admin_approved_at,
    created_at
FROM purchases 
WHERE user_id = 'B43A3D'
ORDER BY created_at DESC;

-- 3. B43A3Dの日利記録確認
SELECT 
    'B43A3D日利記録' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = 'B43A3D'
ORDER BY date DESC;

-- 4. 7A9637の日利記録確認（紹介報酬含む）
SELECT 
    '7A9637日利記録' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '7A9637'
ORDER BY date DESC;

-- 5. B43A3Dのaffiliate_cycle状況確認
SELECT 
    'B43A3D_affiliate_cycle' as check_type,
    user_id,
    total_nft_count,
    cum_usdt,
    available_usdt,
    auto_nft_count,
    manual_nft_count,
    next_action,
    cycle_number,
    cycle_start_date,
    updated_at
FROM affiliate_cycle 
WHERE user_id = 'B43A3D';

-- 6. 7/16と7/17の日利設定確認
SELECT 
    '日利設定確認' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log 
WHERE date IN ('2025-07-16', '2025-07-17')
ORDER BY date DESC;

-- 7. 7A9637 → 6E1304 → B43A3D の紹介ツリー確認
SELECT 
    '紹介ツリー確認' as check_type,
    u1.user_id as level0_user,
    u1.email as level0_email,
    u2.user_id as level1_user,
    u2.email as level1_email,
    u3.user_id as level2_user,
    u3.email as level2_email,
    u1.has_approved_nft as level0_active,
    u2.has_approved_nft as level1_active,
    u3.has_approved_nft as level2_active
FROM users u1
LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
WHERE u1.user_id = '7A9637'
AND u2.user_id = '6E1304'
AND u3.user_id = 'B43A3D';

-- 8. 今日の日利処理実行確認
SELECT 
    'システムログ確認' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%daily_yield%'
AND DATE(created_at) = CURRENT_DATE
ORDER BY created_at DESC
LIMIT 10;

-- 9. B43A3Dの運用開始日計算確認
SELECT 
    'B43A3D運用開始日確認' as check_type,
    user_id,
    MAX(admin_approved_at::date) as latest_approval_date,
    MAX(admin_approved_at::date) + INTERVAL '15 days' as operation_start_date,
    CASE 
        WHEN MAX(admin_approved_at::date) + INTERVAL '15 days' <= CURRENT_DATE THEN '運用開始済み'
        ELSE '運用開始前'
    END as operation_status
FROM purchases 
WHERE user_id = 'B43A3D'
AND admin_approved = true
GROUP BY user_id;

-- 10. 紹介報酬計算関数の存在確認
SELECT 
    '紹介報酬関数確認' as check_type,
    routine_name,
    routine_type,
    CASE 
        WHEN routine_definition LIKE '%calculate_and_distribute_referral_bonuses%' THEN '関数呼び出しあり'
        ELSE '関数呼び出しなし'
    END as function_call_status
FROM information_schema.routines 
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 11. 手動でB43A3Dの紹介報酬計算テスト
SELECT 
    'B43A3D紹介報酬計算テスト' as check_type,
    udp.user_id,
    udp.date,
    udp.daily_profit as b43a3d_profit,
    udp.daily_profit * 0.10 as expected_level2_bonus_for_7a9637,
    '7A9637が受け取るべきLevel2報酬' as note
FROM user_daily_profit udp
WHERE udp.user_id = 'B43A3D'
AND udp.date >= '2025-07-16'
ORDER BY udp.date DESC;