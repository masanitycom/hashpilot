-- HASHPILOT利益$0問題の調査スクリプト
-- 作成日: 2025-07-17
-- 目的: なぜ全ての利益が$0になっているかを調査

-- 1. user_daily_profitテーブルのデータ確認
SELECT 
    'user_daily_profit最新10件' as section,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit
ORDER BY date DESC, created_at DESC
LIMIT 10;

-- 2. user_daily_profitの集計
SELECT 
    'user_daily_profit集計' as section,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(daily_profit) as total_profit,
    MAX(date) as latest_date,
    MIN(date) as earliest_date
FROM user_daily_profit;

-- 3. affiliate_cycleテーブルのデータ確認
SELECT 
    'affiliate_cycle最新10件' as section,
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    available_usdt,
    auto_nft_count,
    manual_nft_count,
    cycle_number,
    cycle_start_date,
    next_action,
    updated_at
FROM affiliate_cycle
ORDER BY updated_at DESC
LIMIT 10;

-- 4. purchasesテーブルで承認されたNFTの確認
SELECT 
    'purchases承認済み最新10件' as section,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    admin_approved_at + INTERVAL '15 days' as operation_start_date,
    CURRENT_DATE - (admin_approved_at::date + 15) as days_since_operation_start,
    created_at
FROM purchases
WHERE admin_approved = true
ORDER BY admin_approved_at DESC
LIMIT 10;

-- 5. 運用開始日が到達したユーザーの確認
SELECT 
    '運用開始済みユーザー' as section,
    p.user_id,
    u.email,
    p.nft_quantity,
    p.admin_approved_at,
    p.admin_approved_at + INTERVAL '15 days' as operation_start_date,
    CURRENT_DATE - (p.admin_approved_at::date + 15) as days_operational
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
  AND (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE
ORDER BY p.admin_approved_at;

-- 6. 今日利益を受け取るべきユーザーの数
SELECT 
    '今日利益を受け取るべきユーザー数' as section,
    COUNT(DISTINCT p.user_id) as eligible_user_count,
    SUM(p.nft_quantity) as total_nfts
FROM purchases p
WHERE p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
  AND (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE;

-- 7. daily_yield_logの最新設定確認
SELECT 
    'daily_yield_log最新設定' as section,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;

-- 8. 特定ユーザー(例: 7A9637)の詳細確認
SELECT 
    'ユーザー7A9637の状況' as section,
    'purchases' as table_name,
    p.nft_quantity,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_at + INTERVAL '15 days' as operation_start_date,
    CASE 
        WHEN (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE 
        THEN '運用開始済み'
        ELSE '運用開始前'
    END as status
FROM purchases p
WHERE p.user_id = '7A9637'
  AND p.admin_approved = true;

-- 9. ユーザー7A9637の利益履歴
SELECT 
    'ユーザー7A9637の利益履歴' as section,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 10. process_daily_yield_with_cycles関数の実行状況確認
SELECT 
    'システムログ確認' as section,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs
WHERE operation LIKE '%daily_yield%'
   OR operation LIKE '%profit%'
ORDER BY created_at DESC
LIMIT 20;