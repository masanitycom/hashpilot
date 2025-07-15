-- 8人の未承認購入ユーザーの現在状況を詳細確認

WITH target_users AS (
    SELECT unnest(ARRAY['Y9FVT1', '794682', '0E47BC', '8C1259', '38A16C', 'B43A3D', '764C02', '7B2CDF']) as user_id
),
user_purchase_details AS (
    SELECT 
        p.user_id,
        u.email,
        COUNT(*) as total_purchases,
        COUNT(CASE WHEN p.admin_approved = true THEN 1 END) as approved_purchases,
        COUNT(CASE WHEN p.admin_approved = false THEN 1 END) as pending_purchases,
        SUM(CASE WHEN p.admin_approved = true THEN p.amount_usd::DECIMAL ELSE 0 END) as approved_amount,
        SUM(CASE WHEN p.admin_approved = false THEN p.amount_usd::DECIMAL ELSE 0 END) as pending_amount,
        MIN(CASE WHEN p.admin_approved = true THEN p.admin_approved_at END) as first_approval_date
    FROM target_users tu
    JOIN purchases p ON tu.user_id = p.user_id
    JOIN users u ON p.user_id = u.user_id
    GROUP BY p.user_id, u.email
),
user_profit_status AS (
    SELECT 
        user_id,
        COUNT(*) as profit_days,
        SUM(daily_profit::DECIMAL) as total_profit,
        MAX(date) as latest_profit_date
    FROM user_daily_profit
    WHERE user_id = ANY(ARRAY['Y9FVT1', '794682', '0E47BC', '8C1259', '38A16C', 'B43A3D', '764C02', '7B2CDF'])
    GROUP BY user_id
),
user_cycle_status AS (
    SELECT 
        user_id,
        available_usdt,
        cum_usdt,
        total_nft_count,
        phase
    FROM affiliate_cycle
    WHERE user_id = ANY(ARRAY['Y9FVT1', '794682', '0E47BC', '8C1259', '38A16C', 'B43A3D', '764C02', '7B2CDF'])
)
SELECT 
    upd.user_id,
    upd.email,
    upd.total_purchases,
    upd.approved_purchases,
    upd.pending_purchases,
    upd.approved_amount as current_approved_investment,
    upd.pending_amount as pending_investment,
    COALESCE(ups.total_profit, 0) as current_total_profit,
    COALESCE(ups.profit_days, 0) as profit_days,
    COALESCE(ucs.available_usdt, 0) as available_usdt,
    COALESCE(ucs.total_nft_count, 0) as current_nft_count,
    CASE 
        WHEN upd.approved_purchases > 0 AND ups.total_profit > 0 THEN '⚠️ 既に投資・利益あり - 削除推奨'
        WHEN upd.approved_purchases > 0 THEN '⚠️ 既に投資あり - 削除推奨'
        WHEN upd.approved_purchases = 0 THEN '✅ 削除しても問題なし'
        ELSE '❓ 要確認'
    END as deletion_recommendation,
    upd.first_approval_date
FROM user_purchase_details upd
LEFT JOIN user_profit_status ups ON upd.user_id = ups.user_id
LEFT JOIN user_cycle_status ucs ON upd.user_id = ucs.user_id
ORDER BY upd.approved_amount DESC, ups.total_profit DESC;

-- 削除対象を明確化
SELECT 
    '=== 削除推奨リスト ===' as summary,
    COUNT(*) as users_with_existing_investment,
    SUM(approved_amount) as total_existing_investment,
    SUM(COALESCE(total_profit, 0)) as total_existing_profit
FROM (
    SELECT 
        upd.user_id,
        upd.approved_amount,
        ups.total_profit
    FROM user_purchase_details upd
    LEFT JOIN user_profit_status ups ON upd.user_id = ups.user_id
    WHERE upd.approved_purchases > 0
) existing_investments;