-- ========================================
-- 報酬と自動購入の問題を調査
-- ========================================

-- 1. 現在の状態を確認
SELECT
    '現在のaffiliate_cycle状態' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt as 紹介報酬累積,
    available_usdt as 出金可能額,
    phase,
    cycle_number
FROM affiliate_cycle
WHERE total_nft_count > 0
ORDER BY user_id
LIMIT 10;

-- 2. 最近の日利データ
SELECT
    '最近の日利データ' as section,
    user_id,
    date,
    daily_profit,
    yield_rate
FROM user_daily_profit
ORDER BY date DESC, user_id
LIMIT 20;

-- 3. 自動購入履歴
SELECT
    '自動購入履歴' as section,
    p.user_id,
    p.nft_quantity,
    p.amount_usd,
    p.admin_approved_at,
    p.cycle_number_at_purchase,
    ac.available_usdt as 現在の出金可能額,
    ac.cum_usdt as 現在の紹介報酬
FROM purchases p
LEFT JOIN affiliate_cycle ac ON p.user_id = ac.user_id
WHERE p.is_auto_purchase = true
ORDER BY p.admin_approved_at DESC
LIMIT 10;

-- 4. 特定ユーザーの詳細（自動購入があったユーザー）
WITH auto_purchase_users AS (
    SELECT DISTINCT user_id
    FROM purchases
    WHERE is_auto_purchase = true
    LIMIT 1
)
SELECT
    '自動購入ユーザーの詳細' as section,
    nm.user_id,
    nm.nft_type,
    nm.nft_sequence,
    nm.nft_value,
    nm.acquired_date,
    COALESCE(SUM(ndp.daily_profit), 0) as 累積日利
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.user_id IN (SELECT user_id FROM auto_purchase_users)
  AND nm.buyback_date IS NULL
GROUP BY nm.user_id, nm.nft_type, nm.nft_sequence, nm.nft_value, nm.acquired_date
ORDER BY nm.nft_sequence;

-- 5. 日利処理のログ
SELECT
    '日利処理ログ' as section,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;
