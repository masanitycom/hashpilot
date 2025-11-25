-- ========================================
-- ユーザー7A9637のダッシュボードデータ確認
-- ========================================

-- 1. ユーザー基本情報
SELECT
    '1. ユーザー基本情報' as section,
    user_id,
    email,
    total_purchases,
    operation_start_date,
    has_approved_nft,
    is_pegasus_exchange,
    created_at
FROM users
WHERE user_id = '7A9637';

-- 2. NFT保有状況
SELECT
    '2. NFT保有状況' as section,
    id,
    purchase_date,
    amount_usd,
    buyback_date,
    is_auto_purchase,
    CASE
        WHEN buyback_date IS NULL THEN '✅ 運用中'
        ELSE '❌ 買い取り済み'
    END as status
FROM nft_master
WHERE user_id = '7A9637'
ORDER BY purchase_date DESC;

-- 3. affiliate_cycle（サイクル情報）
SELECT
    '3. サイクル情報' as section,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    cycle_count
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 4. daily_yield_log_v2（システム全体の日利設定）
SELECT
    '4. システム全体の日利設定（直近10日）' as section,
    date,
    total_profit_amount,
    total_nft_count,
    cumulative_gross_profit,
    cumulative_net_profit,
    daily_pnl,
    distribution_dividend,
    CASE
        WHEN daily_pnl > 0 THEN '✅ プラス配当'
        WHEN daily_pnl = 0 THEN '⚠️ ゼロ'
        ELSE '❌ マイナス'
    END as status
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- 5. nft_daily_profit（このユーザーのNFT日利履歴）
SELECT
    '5. nft_daily_profit（7A9637・直近10日）' as section,
    ndp.date,
    ndp.nft_id,
    ndp.daily_profit,
    ndp.yield_rate,
    ndp.user_rate,
    ndp.base_amount,
    ndp.phase
FROM nft_daily_profit ndp
WHERE ndp.user_id = '7A9637'
ORDER BY ndp.date DESC, ndp.nft_id
LIMIT 20;

-- 6. user_daily_profit VIEW（このユーザーの集計日利）
SELECT
    '6. user_daily_profit VIEW（7A9637・直近10日）' as section,
    date,
    daily_profit,
    yield_rate,
    base_amount,
    user_rate
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 7. 昨日の日付のデータ
WITH yesterday AS (
    SELECT CURRENT_DATE - INTERVAL '1 day' as yesterday_date
)
SELECT
    '7. 昨日（' || yesterday_date || '）のデータ' as section,
    COALESCE(udp.daily_profit, 0) as daily_profit,
    COALESCE(udp.yield_rate, 0) as yield_rate,
    CASE
        WHEN udp.daily_profit IS NOT NULL THEN '✅ データあり'
        ELSE '❌ データなし'
    END as status
FROM yesterday
LEFT JOIN user_daily_profit udp ON udp.user_id = '7A9637' AND udp.date = yesterday_date;

-- 8. 今月の累積利益
WITH month_start AS (
    SELECT DATE_TRUNC('month', CURRENT_DATE) as month_start_date
)
SELECT
    '8. 今月の累積利益（7A9637）' as section,
    COUNT(*) as record_count,
    SUM(daily_profit) as monthly_total,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit udp
CROSS JOIN month_start
WHERE udp.user_id = '7A9637'
    AND udp.date >= month_start_date
    AND udp.date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';

-- 9. 紹介報酬（user_referral_profit）
SELECT
    '9. 紹介報酬（7A9637・直近10日）' as section,
    date,
    profit_amount,
    level1_profit,
    level2_profit,
    level3_profit
FROM user_referral_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 10. グラフ用のデータ（直近30日）
SELECT
    '10. グラフデータ（直近30日）' as section,
    date,
    daily_profit as personal_profit,
    COALESCE((
        SELECT profit_amount
        FROM user_referral_profit urp
        WHERE urp.user_id = '7A9637' AND urp.date = udp.date
    ), 0) as referral_profit,
    daily_profit + COALESCE((
        SELECT profit_amount
        FROM user_referral_profit urp
        WHERE urp.user_id = '7A9637' AND urp.date = udp.date
    ), 0) as total_profit
FROM user_daily_profit udp
WHERE udp.user_id = '7A9637'
    AND udp.date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date;

-- 11. ダッシュボードカードの期待値
SELECT
    '11. ダッシュボードカード期待値' as section,
    'DailyProfitCard（昨日の確定日利）' as card_name,
    (SELECT daily_profit FROM user_daily_profit
     WHERE user_id = '7A9637'
     AND date = CURRENT_DATE - INTERVAL '1 day') as expected_value,
    CASE
        WHEN (SELECT daily_profit FROM user_daily_profit
              WHERE user_id = '7A9637'
              AND date = CURRENT_DATE - INTERVAL '1 day') IS NOT NULL
        THEN '✅ 表示されるはず'
        ELSE '❌ 表示されない'
    END as should_display
UNION ALL
SELECT
    '11. ダッシュボードカード期待値' as section,
    'TotalProfitCard（昨日の合計利益）' as card_name,
    (SELECT daily_profit FROM user_daily_profit
     WHERE user_id = '7A9637'
     AND date = CURRENT_DATE - INTERVAL '1 day') +
    COALESCE((SELECT profit_amount FROM user_referral_profit
              WHERE user_id = '7A9637'
              AND date = CURRENT_DATE - INTERVAL '1 day'), 0) as expected_value,
    '計算値' as should_display;

-- 12. 整合性チェック（nft_daily_profit vs user_daily_profit）
WITH nft_sum AS (
    SELECT
        date,
        SUM(daily_profit) as nft_total
    FROM nft_daily_profit
    WHERE user_id = '7A9637'
        AND date >= CURRENT_DATE - INTERVAL '10 days'
    GROUP BY date
)
SELECT
    '12. 整合性チェック（直近10日）' as section,
    COALESCE(ns.date, udp.date) as date,
    ns.nft_total as nft_daily_profit_sum,
    udp.daily_profit as user_daily_profit_view,
    CASE
        WHEN ABS(COALESCE(ns.nft_total, 0) - COALESCE(udp.daily_profit, 0)) < 0.001
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM nft_sum ns
FULL OUTER JOIN user_daily_profit udp
    ON ns.date = udp.date AND udp.user_id = '7A9637'
ORDER BY COALESCE(ns.date, udp.date) DESC;
