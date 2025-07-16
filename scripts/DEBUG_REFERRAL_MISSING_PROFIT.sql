-- 🔍 B43A3Dの日利記録が存在しない問題の調査
-- 2025年7月17日

-- 1. B43A3Dの日利記録確認（全期間）
SELECT 
    'B43A3D日利記録_全期間' as check_type,
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

-- 2. 7/16の日利処理で処理されたユーザー一覧
SELECT 
    '7月16日処理ユーザー' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase
FROM user_daily_profit 
WHERE date = '2025-07-16'
ORDER BY daily_profit DESC;

-- 3. B43A3Dの運用開始日詳細計算
SELECT 
    'B43A3D運用開始日詳細' as check_type,
    user_id,
    admin_approved_at,
    admin_approved_at::date as approval_date,
    (admin_approved_at::date + INTERVAL '14 days') as operation_start_date,
    '2025-07-16' as target_date,
    CASE 
        WHEN (admin_approved_at::date + INTERVAL '14 days') <= '2025-07-16' THEN '運用開始済み'
        ELSE '運用開始前'
    END as operation_status_for_7_16,
    CASE 
        WHEN (admin_approved_at::date + INTERVAL '14 days') <= '2025-07-17' THEN '運用開始済み'
        ELSE '運用開始前'
    END as operation_status_for_7_17
FROM purchases 
WHERE user_id = 'B43A3D'
AND admin_approved = true
ORDER BY admin_approved_at DESC;

-- 4. 7/17の日利処理実行確認
SELECT 
    '7月17日システムログ' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%daily_yield%'
AND DATE(created_at) = '2025-07-17'
ORDER BY created_at DESC;

-- 5. 7/17の日利設定確認
SELECT 
    '7月17日日利設定' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log 
WHERE date = '2025-07-17'
ORDER BY created_at DESC;

-- 6. 7/17の全ユーザー日利記録
SELECT 
    '7月17日全ユーザー日利' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE date = '2025-07-17'
ORDER BY created_at DESC;

-- 7. B43A3Dがaffiliate_cycleに存在するか確認
SELECT 
    'B43A3D_affiliate_cycle存在確認' as check_type,
    ac.user_id,
    ac.total_nft_count,
    ac.cum_usdt,
    u.is_active,
    u.has_approved_nft,
    CASE 
        WHEN ac.user_id IS NULL THEN 'affiliate_cycleに存在しない'
        WHEN ac.total_nft_count = 0 THEN 'NFT数が0'
        WHEN u.is_active = false THEN 'ユーザーが非アクティブ'
        WHEN u.has_approved_nft = false THEN 'NFTが未承認'
        ELSE '正常'
    END as status
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = 'B43A3D';

-- 8. 今日の日利処理実行テスト（B43A3D対象）
SELECT 
    'B43A3D今日の処理対象テスト' as check_type,
    ac.user_id,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.next_action,
    u.is_active,
    u.has_approved_nft,
    MAX(p.admin_approved_at::date) as latest_approval_date,
    MAX(p.admin_approved_at::date) + INTERVAL '14 days' as operation_start_date,
    CASE 
        WHEN MAX(p.admin_approved_at::date) + INTERVAL '14 days' <= CURRENT_DATE THEN '今日から運用開始可能'
        ELSE '運用開始前'
    END as today_operation_status
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN purchases p ON ac.user_id = p.user_id AND p.admin_approved = true
WHERE ac.user_id = 'B43A3D'
GROUP BY ac.user_id, ac.total_nft_count, ac.cum_usdt, ac.next_action, u.is_active, u.has_approved_nft;

-- 9. 手動でB43A3Dの運用開始日を正確に計算
SELECT 
    'B43A3D運用開始日再計算' as check_type,
    user_id,
    admin_approved_at,
    admin_approved_at::date as approval_date,
    (admin_approved_at::date + INTERVAL '14 days')::date as operation_start_date,
    CURRENT_DATE as today,
    CASE 
        WHEN (admin_approved_at::date + INTERVAL '14 days')::date <= CURRENT_DATE THEN '運用開始済み'
        ELSE FORMAT('運用開始予定日: %s', (admin_approved_at::date + INTERVAL '14 days')::date)
    END as operation_status
FROM purchases 
WHERE user_id = 'B43A3D'
AND admin_approved = true
ORDER BY admin_approved_at DESC;

-- 10. 今日（7/17）にB43A3Dの日利処理が実行されるかテスト
SELECT 
    'B43A3D今日の処理可否' as check_type,
    'B43A3D' as user_id,
    CURRENT_DATE as today,
    '2025-07-02'::date as latest_approval_date,
    ('2025-07-02'::date + INTERVAL '14 days')::date as operation_start_date,
    CASE 
        WHEN ('2025-07-02'::date + INTERVAL '14 days')::date <= CURRENT_DATE THEN '今日処理される'
        ELSE '今日は処理されない'
    END as processing_status;