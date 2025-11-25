-- ========================================
-- ユーザー7A9637のダッシュボードデータ確認（修正版2）
-- ========================================

-- 1. ユーザー基本情報
SELECT
    '1. ユーザー基本情報' as section,
    user_id,
    email,
    total_purchases,
    operation_start_date,
    has_approved_nft,
    is_pegasus_exchange
FROM users
WHERE user_id = '7A9637';

-- 2. NFT保有状況
SELECT
    '2. NFT保有状況' as section,
    id,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date,
    CASE
        WHEN buyback_date IS NULL THEN '✅ 運用中'
        ELSE '❌ 買い取り済み'
    END as status
FROM nft_master
WHERE user_id = '7A9637'
ORDER BY acquired_date DESC;

-- 3. affiliate_cycle（サイクル情報）
SELECT
    '3. サイクル情報' as section,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 4. daily_yield_log（システム全体の日利設定・直近10日）
SELECT
    '4. システム全体の日利設定' as section,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

-- 5. nft_daily_profit（このユーザーのNFT日利履歴・直近10日）
SELECT
    '5. nft_daily_profit（7A9637）' as section,
    date,
    nft_id,
    daily_profit,
    yield_rate,
    created_at
FROM nft_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC, nft_id
LIMIT 20;

-- 6. user_daily_profit VIEW（このユーザーの集計日利・直近10日）
SELECT
    '6. user_daily_profit VIEW（7A9637）' as section,
    date,
    daily_profit,
    yield_rate
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 7. 重要：11/11, 11/12, 11/13のデータ有無確認
SELECT
    '7. 日付別データ確認（11/11, 11/12, 11/13）' as section,
    '2025-11-11' as check_date,
    COALESCE(udp.daily_profit, 0) as daily_profit,
    CASE WHEN udp.daily_profit IS NOT NULL THEN '✅ あり' ELSE '❌ なし' END as status
FROM users u
LEFT JOIN user_daily_profit udp ON udp.user_id = u.user_id AND udp.date = '2025-11-11'
WHERE u.user_id = '7A9637'
UNION ALL
SELECT
    '7. 日付別データ確認（11/11, 11/12, 11/13）',
    '2025-11-12',
    COALESCE(udp.daily_profit, 0),
    CASE WHEN udp.daily_profit IS NOT NULL THEN '✅ あり' ELSE '❌ なし' END
FROM users u
LEFT JOIN user_daily_profit udp ON udp.user_id = u.user_id AND udp.date = '2025-11-12'
WHERE u.user_id = '7A9637'
UNION ALL
SELECT
    '7. 日付別データ確認（11/11, 11/12, 11/13）',
    '2025-11-13',
    COALESCE(udp.daily_profit, 0),
    CASE WHEN udp.daily_profit IS NOT NULL THEN '✅ あり' ELSE '❌ なし' END
FROM users u
LEFT JOIN user_daily_profit udp ON udp.user_id = u.user_id AND udp.date = '2025-11-13'
WHERE u.user_id = '7A9637';

-- 8. 紹介報酬（直近10日）
SELECT
    '8. 紹介報酬（7A9637）' as section,
    date,
    profit_amount,
    level1_profit,
    level2_profit,
    level3_profit
FROM user_referral_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 9. 今月の累積利益（11月）
SELECT
    '9. 今月の累積利益（11月）' as section,
    COUNT(*) as record_count,
    COALESCE(SUM(daily_profit), 0) as monthly_total,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit
WHERE user_id = '7A9637'
    AND date >= '2025-11-01'
    AND date < '2025-12-01';
