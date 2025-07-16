-- 7A9637利益異常調査スクリプト
-- 2025年1月16日作成
-- 目的: なぜ7A9637だけに利益が発生し、他のユーザーに利益が発生しないのかを特定

-- 1. 7A9637ユーザーの完全な情報
SELECT 
    'STEP_1_7A9637_COMPLETE_INFO' as investigation_step,
    u.user_id,
    u.email,
    u.full_name,
    u.total_purchases,
    u.is_active,
    u.has_approved_nft,
    u.created_at as user_created_at,
    u.referrer_user_id
FROM users u 
WHERE u.user_id = '7A9637';

-- 2. 7A9637の購入履歴（すべて）
SELECT 
    'STEP_2_7A9637_PURCHASES' as investigation_step,
    p.user_id,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.is_auto_purchase,
    p.created_at as purchase_created_at,
    p.purchase_date,
    -- 運用開始日の計算
    CASE 
        WHEN p.admin_approved IS NOT NULL THEN p.admin_approved + INTERVAL '15 days'
        ELSE NULL
    END as operation_start_date,
    -- 現在運用中かどうか
    CASE 
        WHEN p.admin_approved IS NOT NULL AND CURRENT_DATE >= p.admin_approved + INTERVAL '15 days' THEN 'ACTIVE'
        WHEN p.admin_approved IS NOT NULL AND CURRENT_DATE < p.admin_approved + INTERVAL '15 days' THEN 'WAITING'
        ELSE 'NOT_APPROVED'
    END as operation_status
FROM purchases p
WHERE p.user_id = '7A9637'
ORDER BY p.created_at DESC;

-- 3. 7A9637のaffiliate_cycle状況
SELECT 
    'STEP_3_7A9637_AFFILIATE_CYCLE' as investigation_step,
    ac.user_id,
    ac.phase,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.auto_nft_count,
    ac.manual_nft_count,
    ac.cycle_number,
    ac.next_action,
    ac.cycle_start_date,
    ac.updated_at
FROM affiliate_cycle ac
WHERE ac.user_id = '7A9637';

-- 4. 7A9637の日利記録（すべて）
SELECT 
    'STEP_4_7A9637_DAILY_PROFIT' as investigation_step,
    udp.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    udp.created_at
FROM user_daily_profit udp
WHERE udp.user_id = '7A9637'
ORDER BY udp.date DESC;

-- 5. 他のNFT承認済みユーザーの基本情報
SELECT 
    'STEP_5_OTHER_APPROVED_USERS' as investigation_step,
    u.user_id,
    u.email,
    u.full_name,
    u.total_purchases,
    u.is_active,
    u.has_approved_nft,
    u.created_at as user_created_at,
    u.referrer_user_id
FROM users u 
WHERE u.has_approved_nft = true 
  AND u.user_id != '7A9637'
ORDER BY u.created_at DESC;

-- 6. 他のユーザーの購入履歴と運用開始状況
SELECT 
    'STEP_6_OTHER_USERS_PURCHASES' as investigation_step,
    p.user_id,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.is_auto_purchase,
    p.created_at as purchase_created_at,
    p.purchase_date,
    -- 運用開始日の計算
    CASE 
        WHEN p.admin_approved IS NOT NULL THEN p.admin_approved + INTERVAL '15 days'
        ELSE NULL
    END as operation_start_date,
    -- 現在運用中かどうか
    CASE 
        WHEN p.admin_approved IS NOT NULL AND CURRENT_DATE >= p.admin_approved + INTERVAL '15 days' THEN 'ACTIVE'
        WHEN p.admin_approved IS NOT NULL AND CURRENT_DATE < p.admin_approved + INTERVAL '15 days' THEN 'WAITING'
        ELSE 'NOT_APPROVED'
    END as operation_status
FROM purchases p
WHERE p.user_id IN (
    SELECT u.user_id 
    FROM users u 
    WHERE u.has_approved_nft = true 
      AND u.user_id != '7A9637'
)
ORDER BY p.user_id, p.created_at DESC;

-- 7. 他のユーザーのaffiliate_cycle状況
SELECT 
    'STEP_7_OTHER_USERS_CYCLES' as investigation_step,
    ac.user_id,
    ac.phase,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.auto_nft_count,
    ac.manual_nft_count,
    ac.cycle_number,
    ac.next_action,
    ac.cycle_start_date,
    ac.updated_at
FROM affiliate_cycle ac
WHERE ac.user_id IN (
    SELECT u.user_id 
    FROM users u 
    WHERE u.has_approved_nft = true 
      AND u.user_id != '7A9637'
)
ORDER BY ac.user_id;

-- 8. 他のユーザーの日利記録
SELECT 
    'STEP_8_OTHER_USERS_DAILY_PROFIT' as investigation_step,
    udp.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    udp.created_at
FROM user_daily_profit udp
WHERE udp.user_id IN (
    SELECT u.user_id 
    FROM users u 
    WHERE u.has_approved_nft = true 
      AND u.user_id != '7A9637'
)
ORDER BY udp.user_id, udp.date DESC;

-- 9. 全user_daily_profitテーブルの内容
SELECT 
    'STEP_9_ALL_DAILY_PROFITS' as investigation_step,
    udp.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    udp.created_at
FROM user_daily_profit udp
ORDER BY udp.date DESC, udp.user_id;

-- 10. 最新の日利設定ログ
SELECT 
    'STEP_10_LATEST_YIELD_SETTINGS' as investigation_step,
    dyl.date,
    dyl.yield_rate,
    dyl.margin_rate,
    dyl.user_rate,
    dyl.is_month_end,
    dyl.created_at
FROM daily_yield_log dyl
ORDER BY dyl.date DESC
LIMIT 10;

-- 11. 利益処理に関するシステムログ
SELECT 
    'STEP_11_SYSTEM_LOGS' as investigation_step,
    sl.log_type,
    sl.operation,
    sl.user_id,
    sl.message,
    sl.details,
    sl.created_at
FROM system_logs sl
WHERE sl.operation LIKE '%yield%' 
   OR sl.operation LIKE '%profit%'
   OR sl.operation LIKE '%cycle%'
ORDER BY sl.created_at DESC
LIMIT 20;

-- 12. 運用開始条件を満たしているユーザーの特定
SELECT 
    'STEP_12_ELIGIBLE_USERS' as investigation_step,
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.is_active,
    p.admin_approved,
    p.admin_approved + INTERVAL '15 days' as operation_start_date,
    CURRENT_DATE as today,
    CASE 
        WHEN CURRENT_DATE >= p.admin_approved + INTERVAL '15 days' THEN 'SHOULD_BE_ACTIVE'
        ELSE 'WAITING'
    END as expected_status,
    -- affiliate_cycleにレコードがあるかチェック
    CASE 
        WHEN ac.user_id IS NOT NULL THEN 'HAS_CYCLE'
        ELSE 'NO_CYCLE'
    END as cycle_status,
    -- 利益記録があるかチェック
    CASE 
        WHEN udp.user_id IS NOT NULL THEN 'HAS_PROFIT'
        ELSE 'NO_PROFIT'
    END as profit_status
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved IS NOT NULL
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true 
  AND u.is_active = true
  AND p.admin_approved IS NOT NULL
GROUP BY u.user_id, u.email, u.has_approved_nft, u.is_active, p.admin_approved, ac.user_id, udp.user_id
ORDER BY u.user_id;

-- 13. 問題の仮説検証
-- 仮説1: RLSポリシーが特定のユーザーのみを処理対象にしている
SELECT 
    'STEP_13_RLS_HYPOTHESIS' as investigation_step,
    'Checking if RLS policies limit processing to specific users' as hypothesis,
    COUNT(*) as total_users,
    COUNT(CASE WHEN udp.user_id IS NOT NULL THEN 1 END) as users_with_profit,
    COUNT(CASE WHEN ac.user_id IS NOT NULL THEN 1 END) as users_with_cycle
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true;

-- 14. 特定のユーザーID形式の検証
SELECT 
    'STEP_14_USER_ID_PATTERN' as investigation_step,
    u.user_id,
    LENGTH(u.user_id) as id_length,
    CASE 
        WHEN u.user_id ~ '^[0-9A-F]{6}$' THEN 'VALID_FORMAT'
        ELSE 'INVALID_FORMAT'
    END as id_format,
    CASE 
        WHEN udp.user_id IS NOT NULL THEN 'HAS_PROFIT'
        ELSE 'NO_PROFIT'
    END as profit_status
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true
ORDER BY u.user_id;

-- 15. 最終分析サマリー
SELECT 
    'STEP_15_FINAL_ANALYSIS' as investigation_step,
    'SUMMARY' as analysis_type,
    'Total approved users: ' || COUNT(DISTINCT u.user_id) as metric_1,
    'Users with profit records: ' || COUNT(DISTINCT udp.user_id) as metric_2,
    'Users with cycle records: ' || COUNT(DISTINCT ac.user_id) as metric_3,
    'Users eligible for profit (15+ days): ' || COUNT(DISTINCT CASE 
        WHEN p.admin_approved IS NOT NULL 
         AND CURRENT_DATE >= p.admin_approved + INTERVAL '15 days' 
        THEN u.user_id 
    END) as metric_4
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved IS NOT NULL
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true;