-- ========================================
-- 運用開始前ユーザーのサイクル問題調査
-- ========================================

-- 1. 投資額$1,000 & Level1-3投資額$54,000のユーザーを特定
SELECT
    '1. ユーザー特定' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    u.has_approved_nft,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 運用開始日未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス,
    u.created_at
FROM users u
WHERE u.total_purchases = 1000
    AND (u.operation_start_date IS NULL OR u.operation_start_date > CURRENT_DATE)
ORDER BY u.created_at DESC
LIMIT 10;

-- 2. そのユーザーのaffiliate_cycle情報
WITH target_user AS (
    SELECT user_id
    FROM users
    WHERE total_purchases = 1000
        AND (operation_start_date IS NULL OR operation_start_date > CURRENT_DATE)
    LIMIT 1
)
SELECT
    '2. affiliate_cycle情報' as section,
    ac.user_id,
    ac.total_nft_count,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.cum_usdt as 累積USDT,
    ac.available_usdt as 確定USDT,
    ac.phase,
    ac.created_at,
    ac.updated_at
FROM affiliate_cycle ac
WHERE ac.user_id IN (SELECT user_id FROM target_user);

-- 3. そのユーザーのuser_referral_profit（紹介報酬履歴）
WITH target_user AS (
    SELECT user_id
    FROM users
    WHERE total_purchases = 1000
        AND (operation_start_date IS NULL OR operation_start_date > CURRENT_DATE)
    LIMIT 1
)
SELECT
    '3. 紹介報酬履歴' as section,
    urp.date,
    urp.profit_amount,
    urp.level1_profit,
    urp.level2_profit,
    urp.level3_profit,
    urp.created_at
FROM user_referral_profit urp
WHERE urp.user_id IN (SELECT user_id FROM target_user)
ORDER BY urp.date DESC
LIMIT 20;

-- 4. 累積USDTの合計確認
WITH target_user AS (
    SELECT user_id
    FROM users
    WHERE total_purchases = 1000
        AND (operation_start_date IS NULL OR operation_start_date > CURRENT_DATE)
    LIMIT 1
)
SELECT
    '4. 累積USDT検証' as section,
    SUM(urp.profit_amount) as 紹介報酬合計,
    (SELECT cum_usdt FROM affiliate_cycle ac WHERE ac.user_id = tu.user_id) as affiliate_cycle累積,
    ABS(SUM(urp.profit_amount) - (SELECT cum_usdt FROM affiliate_cycle ac WHERE ac.user_id = tu.user_id)) as 差異,
    CASE
        WHEN ABS(SUM(urp.profit_amount) - (SELECT cum_usdt FROM affiliate_cycle ac WHERE ac.user_id = tu.user_id)) < 0.01
        THEN '✅ 一致'
        ELSE '⚠️ 差異あり'
    END as status
FROM target_user tu
LEFT JOIN user_referral_profit urp ON urp.user_id = tu.user_id
GROUP BY tu.user_id;

-- 5. 運用開始前のユーザー全員の状況
SELECT
    '5. 運用開始前ユーザーの紹介報酬状況' as section,
    COUNT(DISTINCT u.user_id) as ユーザー数,
    COUNT(DISTINCT urp.user_id) as 紹介報酬を受け取ったユーザー数,
    SUM(urp.profit_amount) as 紹介報酬合計,
    CASE
        WHEN COUNT(DISTINCT urp.user_id) > 0 THEN '❌ 運用開始前に報酬配布'
        ELSE '✅ 報酬配布なし'
    END as status
FROM users u
LEFT JOIN user_referral_profit urp ON urp.user_id = u.user_id
WHERE u.operation_start_date IS NULL OR u.operation_start_date > CURRENT_DATE;

-- 6. process_daily_yield_v2での紹介報酬配布ロジックを確認
-- （この関数のソースコードは別途確認が必要）
SELECT
    '6. RPC関数の確認' as section,
    'process_daily_yield_v2 の Step 12: アフィリエイト報酬の配分 をチェック' as 説明,
    'operation_start_date のチェックが入っているか確認' as 確認項目;

-- 7. Level1-3投資額の確認（紹介者がいるか）
WITH target_user AS (
    SELECT user_id
    FROM users
    WHERE total_purchases = 1000
        AND (operation_start_date IS NULL OR operation_start_date > CURRENT_DATE)
    LIMIT 1
),
referrals AS (
    SELECT
        u2.user_id,
        u2.total_purchases,
        CASE
            WHEN u2.operation_start_date IS NOT NULL AND u2.operation_start_date <= CURRENT_DATE
            THEN FLOOR(u2.total_purchases / 1100) * 1000
            ELSE 0
        END as investment
    FROM target_user tu
    JOIN users u2 ON u2.referrer_user_id = tu.user_id
    WHERE u2.total_purchases > 0
)
SELECT
    '7. 紹介者の投資額' as section,
    COUNT(*) as 紹介者数,
    SUM(total_purchases) as 紹介者総購入額,
    SUM(investment) as 運用中投資額,
    CASE
        WHEN SUM(investment) > 0 THEN '✅ 運用中の紹介者あり'
        ELSE '⚠️ 全員運用開始前'
    END as status
FROM referrals;
