-- ユーザー794682の詳細調査
-- NFTカウント不整合の原因を特定する
-- 作成日: 2025年10月7日

SELECT '=== 1. ユーザー基本情報 ===' as section;

SELECT
    user_id,
    email,
    full_name,
    referrer_user_id,
    has_approved_nft,
    total_purchases,
    nft_receive_address,
    created_at,
    updated_at
FROM users
WHERE user_id = '794682';

-- 紹介者情報
SELECT '=== 2. 紹介者情報 ===' as section;

SELECT
    user_id,
    email,
    full_name
FROM users
WHERE user_id = (SELECT referrer_user_id FROM users WHERE user_id = '794682');

SELECT '=== 3. affiliate_cycle詳細 ===' as section;

SELECT
    user_id,
    phase,
    cycle_number,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    last_updated,
    created_at
FROM affiliate_cycle
WHERE user_id = '794682';

SELECT '=== 4. purchases テーブル（全ステータス） ===' as section;

SELECT
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    is_auto_purchase,
    created_at,
    updated_at,
    admin_approved_at,
    admin_approved_by
FROM purchases
WHERE user_id = '794682'
ORDER BY created_at DESC;

SELECT '=== 5. nft_master テーブル（buyback含む全て） ===' as section;

SELECT
    id,
    user_id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date,
    created_at,
    updated_at
FROM nft_master
WHERE user_id = '794682'
ORDER BY nft_sequence;

SELECT '=== 6. withdrawals（出金履歴） ===' as section;

SELECT
    id,
    user_id,
    email,
    amount,
    status,
    withdrawal_type,
    created_at,
    completed_at,
    notes
FROM withdrawals
WHERE user_id = '794682'
ORDER BY created_at DESC;

SELECT '=== 7. user_daily_profit（日次利益履歴） ===' as section;

SELECT
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit
WHERE user_id = '794682'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 8. nft_daily_profit（NFT単位の利益履歴） ===' as section;

SELECT
    nft_id,
    date,
    daily_profit,
    yield_rate,
    base_amount,
    phase,
    created_at
FROM nft_daily_profit
WHERE user_id = '794682'
ORDER BY date DESC, nft_id
LIMIT 10;

SELECT '=== 9. auto_purchase_history（自動購入履歴） ===' as section;

SELECT
    id,
    user_id,
    purchase_date,
    nft_quantity,
    cum_usdt_before,
    cum_usdt_after,
    created_at
FROM auto_purchase_history
WHERE user_id = '794682'
ORDER BY purchase_date DESC;

SELECT '=== 10. system_logs（システムログ） ===' as section;

SELECT
    log_type,
    message,
    user_id,
    details,
    created_at
FROM system_logs
WHERE user_id = '794682'
   OR details::text LIKE '%794682%'
ORDER BY created_at DESC
LIMIT 20;

SELECT '=== 11. 他のユーザーとの比較（同じ紹介者配下） ===' as section;

SELECT
    u.user_id,
    u.email,
    ac.total_nft_count as cycle_count,
    COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_nft_count,
    COUNT(p.id) FILTER (WHERE p.admin_approved = true) as purchase_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id
LEFT JOIN purchases p ON u.user_id = p.user_id
WHERE u.referrer_user_id = (SELECT referrer_user_id FROM users WHERE user_id = '794682')
GROUP BY u.user_id, u.email, ac.total_nft_count
ORDER BY u.created_at;

SELECT '=== 12. まとめ ===' as section;

SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM purchases WHERE user_id = '794682' AND admin_approved = true)
        THEN '✅ 購入記録あり（承認済み）'
        WHEN EXISTS (SELECT 1 FROM purchases WHERE user_id = '794682' AND admin_approved = false)
        THEN '⚠️ 購入記録あり（未承認）'
        ELSE '❌ 購入記録なし'
    END as purchase_status,
    CASE
        WHEN EXISTS (SELECT 1 FROM nft_master WHERE user_id = '794682' AND buyback_date IS NULL)
        THEN '✅ 有効なNFTあり'
        WHEN EXISTS (SELECT 1 FROM nft_master WHERE user_id = '794682' AND buyback_date IS NOT NULL)
        THEN '⚠️ バイバック済みNFTあり'
        ELSE '❌ NFT記録なし'
    END as nft_status,
    (SELECT total_nft_count FROM affiliate_cycle WHERE user_id = '794682') as affiliate_cycle_count,
    (SELECT has_approved_nft FROM users WHERE user_id = '794682') as has_approved_nft_flag,
    (SELECT total_purchases FROM users WHERE user_id = '794682') as total_purchases_amount;
