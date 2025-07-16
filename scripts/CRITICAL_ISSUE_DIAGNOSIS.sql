-- 🚨 重大問題：新しい関数が実行されていない
-- 2025年7月17日

-- 1. 現在のprocess_daily_yield_with_cycles関数の定義確認
SELECT 
    '現在の関数定義' as check_type,
    routine_name,
    routine_type,
    LENGTH(routine_definition) as definition_length,
    CASE 
        WHEN routine_definition LIKE '%calculate_and_distribute_referral_bonuses%' THEN '新しい関数（紹介報酬付き）'
        ELSE '古い関数（紹介報酬なし）'
    END as function_version,
    CASE 
        WHEN routine_definition LIKE '%daily_yield_processing_with_referral%' THEN 'ログが新バージョン'
        ELSE 'ログが旧バージョン'
    END as log_version
FROM information_schema.routines 
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 2. calculate_and_distribute_referral_bonuses関数の存在確認
SELECT 
    '紹介報酬関数存在確認' as check_type,
    routine_name,
    routine_type,
    CASE 
        WHEN routine_name IS NOT NULL THEN '存在する'
        ELSE '存在しない'
    END as status
FROM information_schema.routines 
WHERE routine_name = 'calculate_and_distribute_referral_bonuses';

-- 3. 最新のシステムログで使用されている関数確認
SELECT 
    '最新実行関数確認' as check_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%daily_yield%'
ORDER BY created_at DESC
LIMIT 5;

-- 4. B43A3Dの運用開始日に関する矛盾調査
SELECT 
    'B43A3D運用開始日矛盾調査' as check_type,
    user_id,
    admin_approved_at,
    admin_approved_at::date as approval_date,
    (admin_approved_at::date + INTERVAL '14 days')::date as operation_start_date,
    '2025-07-16' as yesterday,
    CASE 
        WHEN (admin_approved_at::date + INTERVAL '14 days')::date <= '2025-07-16' THEN '7/16に処理されるべき'
        ELSE '7/16は処理されない'
    END as should_process_on_7_16
FROM purchases 
WHERE user_id = 'B43A3D'
AND admin_approved = true
ORDER BY admin_approved_at DESC;

-- 5. 7/16の日利処理でB43A3Dが除外された理由調査
-- 関数内のWHERE条件をチェック
SELECT 
    'B43A3D除外理由調査' as check_type,
    ac.user_id,
    ac.total_nft_count,
    u.is_active,
    u.has_approved_nft,
    MAX(p.admin_approved_at::date) as latest_approval,
    (MAX(p.admin_approved_at::date) + INTERVAL '14 days')::date as calculated_start_date,
    '2025-07-16' as processing_date,
    CASE 
        WHEN ac.total_nft_count = 0 THEN 'NFT数が0'
        WHEN u.is_active = false THEN 'ユーザー非アクティブ'
        WHEN u.has_approved_nft = false THEN 'NFT未承認'
        WHEN (MAX(p.admin_approved_at::date) + INTERVAL '14 days')::date > '2025-07-16' THEN '運用開始前'
        ELSE '処理されるべき'
    END as exclusion_reason
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN purchases p ON ac.user_id = p.user_id AND p.admin_approved = true
WHERE ac.user_id = 'B43A3D'
GROUP BY ac.user_id, ac.total_nft_count, u.is_active, u.has_approved_nft;

-- 6. 7/16処理で使用された関数の運用開始日計算ロジック確認
-- 実際の関数内のロジックと結果の比較
SELECT 
    '関数内運用開始日計算' as check_type,
    user_id,
    admin_approved_at,
    admin_approved_at::date as approval_date,
    (admin_approved_at::date + INTERVAL '14 days') as operation_start_datetime,
    '2025-07-16' as processing_date,
    CASE 
        WHEN (admin_approved_at::date + INTERVAL '14 days') < '2025-07-16' THEN '運用開始済み（<）'
        WHEN (admin_approved_at::date + INTERVAL '14 days') <= '2025-07-16' THEN '運用開始済み（<=）'
        ELSE '運用開始前'
    END as operation_status
FROM purchases 
WHERE user_id = 'B43A3D'
AND admin_approved = true
ORDER BY admin_approved_at DESC;

-- 7. 新しい関数実行のテスト
SELECT 
    '新関数実行テスト' as check_type,
    'テスト実行前' as status,
    NOW() as test_time;

-- 8. 手動でcalculate_and_distribute_referral_bonuses関数をテスト
-- B43A3Dの利益$1.44（2NFT x 1000 x 0.00072）に対する紹介報酬計算
SELECT 
    '手動紹介報酬計算' as check_type,
    'B43A3D' as profit_source,
    2 * 1000 * 0.000718 as expected_b43a3d_profit,
    (2 * 1000 * 0.000718) * 0.20 as expected_level1_bonus_for_6e1304,
    (2 * 1000 * 0.000718) * 0.10 as expected_level2_bonus_for_7a9637,
    '6E1304' as level1_referrer,
    '7A9637' as level2_referrer;