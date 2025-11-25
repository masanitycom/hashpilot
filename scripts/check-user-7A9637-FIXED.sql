-- ========================================
-- ユーザー7A9637のダッシュボードデータ確認（修正版）
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

-- 2. NFT保有状況（修正: acquired_dateを使用）
SELECT
    '2. NFT保有状況' as section,
    id,
    nft_sequence,
    nft_type,
    acquired_date,
    nft_value,
    buyback_date,
    CASE
        WHEN buyback_date IS NULL THEN '✅ 運用中'
        ELSE '❌ 買い取り済み'
    END as status
FROM nft_master
WHERE user_id = '7A9637'
ORDER BY nft_sequence;

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

-- 4. daily_yield_log_v2（システム全体の日利設定・直近10日）
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

-- 5. nft_daily_profit（このユーザーのNFT日利履歴・直近10日分）
SELECT
    '5. nft_daily_profit（7A9637・直近10日）' as section,
    date,
    nft_id,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase
FROM nft_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC, nft_id
LIMIT 20;

-- 6. user_daily_profit VIEW（このユーザーの集計日利・直近10日）
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

-- 7. 昨日の詳細データ
WITH yesterday AS (
    SELECT CURRENT_DATE - INTERVAL '1 day' as yesterday_date
)
SELECT
    '7. 昨日のデータ詳細' as section,
    y.yesterday_date as date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    CASE
        WHEN udp.daily_profit IS NOT NULL THEN '✅ データあり'
        ELSE '❌ データなし'
    END as status
FROM yesterday y
LEFT JOIN user_daily_profit udp ON udp.user_id = '7A9637' AND udp.date = y.yesterday_date;

-- 8. 昨日のnft_daily_profitレコード数
WITH yesterday AS (
    SELECT CURRENT_DATE - INTERVAL '1 day' as yesterday_date
)
SELECT
    '8. 昨日のnft_daily_profitレコード数' as section,
    COUNT(*) as nft_record_count,
    SUM(daily_profit) as total_from_nft_table
FROM nft_daily_profit ndp
CROSS JOIN yesterday y
WHERE ndp.user_id = '7A9637' AND ndp.date = y.yesterday_date;

-- 9. 今月の累積利益
SELECT
    '9. 今月の累積利益（7A9637）' as section,
    COUNT(*) as days_with_data,
    SUM(daily_profit) as monthly_total,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit
WHERE user_id = '7A9637'
    AND date >= DATE_TRUNC('month', CURRENT_DATE)
    AND date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';

-- 10. 紹介報酬（user_referral_profit・直近10日）
SELECT
    '10. 紹介報酬（7A9637・直近10日）' as section,
    date,
    profit_amount,
    level1_profit,
    level2_profit,
    level3_profit
FROM user_referral_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 11. 昨日の紹介報酬
WITH yesterday AS (
    SELECT CURRENT_DATE - INTERVAL '1 day' as yesterday_date
)
SELECT
    '11. 昨日の紹介報酬' as section,
    COALESCE(urp.profit_amount, 0) as yesterday_referral_profit
FROM yesterday y
LEFT JOIN user_referral_profit urp ON urp.user_id = '7A9637' AND urp.date = y.yesterday_date;

-- 12. ダッシュボードカードの期待値（昨日の日付で）
WITH yesterday AS (
    SELECT CURRENT_DATE - INTERVAL '1 day' as yesterday_date
)
SELECT
    '12. ダッシュボードカード期待値' as section,
    'DailyProfitCard' as card_name,
    udp.daily_profit as personal_profit,
    udp.user_rate as user_rate,
    CASE
        WHEN udp.user_rate IS NOT NULL THEN CONCAT(udp.user_rate * 100, '%')
        ELSE 'NULL'
    END as user_rate_display,
    CASE
        WHEN udp.daily_profit IS NOT NULL THEN '✅ 表示されるはず'
        ELSE '❌ データなし'
    END as should_display
FROM yesterday y
LEFT JOIN user_daily_profit udp ON udp.user_id = '7A9637' AND udp.date = y.yesterday_date

UNION ALL

SELECT
    '12. ダッシュボードカード期待値' as section,
    'PersonalProfitCard' as card_name,
    udp.daily_profit as personal_profit,
    NULL as user_rate,
    NULL as user_rate_display,
    CASE
        WHEN udp.daily_profit IS NOT NULL THEN '✅ 表示されるはず'
        ELSE '❌ データなし'
    END as should_display
FROM yesterday y
LEFT JOIN user_daily_profit udp ON udp.user_id = '7A9637' AND udp.date = y.yesterday_date

UNION ALL

SELECT
    '12. ダッシュボードカード期待値' as section,
    'TotalProfitCard' as card_name,
    COALESCE(udp.daily_profit, 0) + COALESCE(urp.profit_amount, 0) as total_profit,
    NULL as user_rate,
    NULL as user_rate_display,
    '昨日の合計利益' as should_display
FROM yesterday y
LEFT JOIN user_daily_profit udp ON udp.user_id = '7A9637' AND udp.date = y.yesterday_date
LEFT JOIN user_referral_profit urp ON urp.user_id = '7A9637' AND urp.date = y.yesterday_date;

-- 13. user_daily_profitビューの定義を確認
SELECT
    '13. user_daily_profitビューの定義' as section,
    pg_get_viewdef('user_daily_profit', true) as view_definition;
