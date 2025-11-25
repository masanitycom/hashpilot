-- ========================================
-- ユーザー7A9637の本番環境データを確認
-- ========================================

-- ========================================
-- 1. ユーザー基本情報
-- ========================================
SELECT
    'ユーザー基本情報' as label,
    user_id,
    full_name,
    email,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    created_at,
    updated_at
FROM users
WHERE user_id = '7A9637';

-- ========================================
-- 2. NFT保有状況
-- ========================================
SELECT
    'NFT保有状況' as label,
    id,
    user_id,
    nft_type,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '7A9637'
ORDER BY acquired_date DESC;

-- ========================================
-- 3. 個人利益（最新10件）
-- ========================================
SELECT
    '個人利益（最新10件）' as label,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_daily_profit,
    phase
FROM nft_daily_profit
WHERE user_id = '7A9637'
GROUP BY date, phase
ORDER BY date DESC
LIMIT 10;

-- ========================================
-- 4. 紹介報酬（最新10件）
-- ========================================
SELECT
    '紹介報酬（最新10件）' as label,
    date,
    referral_level,
    COUNT(*) as record_count,
    SUM(profit_amount) as total_referral,
    MIN(profit_amount) as min_amount,
    MAX(profit_amount) as max_amount
FROM user_referral_profit
WHERE user_id = '7A9637'
GROUP BY date, referral_level
ORDER BY date DESC, referral_level
LIMIT 20;

-- ========================================
-- 5. マイナスの紹介報酬レコード
-- ========================================
SELECT
    '★ マイナスの紹介報酬' as issue,
    date,
    referral_level,
    child_user_id,
    profit_amount,
    created_at
FROM user_referral_profit
WHERE user_id = '7A9637'
    AND profit_amount < 0
ORDER BY date DESC, referral_level;

-- ========================================
-- 6. 紹介報酬の元になった子ユーザーの日利
-- ========================================
SELECT
    '紹介報酬の元データ（最新5日）' as label,
    urp.date,
    urp.referral_level,
    urp.child_user_id,
    u.full_name as child_name,
    u.is_pegasus_exchange as child_is_pegasus,
    urp.profit_amount as referral_amount,
    ndp.daily_profit as child_daily_profit,
    CASE
        WHEN urp.referral_level = 1 THEN ndp.daily_profit * 0.20
        WHEN urp.referral_level = 2 THEN ndp.daily_profit * 0.10
        WHEN urp.referral_level = 3 THEN ndp.daily_profit * 0.05
    END as expected_referral
FROM user_referral_profit urp
LEFT JOIN users u ON urp.child_user_id = u.user_id
LEFT JOIN (
    SELECT user_id, date, SUM(daily_profit) as daily_profit
    FROM nft_daily_profit
    GROUP BY user_id, date
) ndp ON urp.child_user_id = ndp.user_id AND urp.date = ndp.date
WHERE urp.user_id = '7A9637'
ORDER BY urp.date DESC, urp.referral_level
LIMIT 30;

-- ========================================
-- 7. affiliate_cycleの状態
-- ========================================
SELECT
    'affiliate_cycleの状態' as label,
    user_id,
    cum_usdt,
    available_usdt,
    phase,
    auto_nft_count,
    manual_nft_count,
    total_nft_count,
    updated_at
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- ========================================
-- 8. 累積の個人利益と紹介報酬
-- ========================================
SELECT
    '累積サマリー' as label,
    (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '7A9637') as total_personal_profit,
    (SELECT COALESCE(SUM(profit_amount), 0) FROM user_referral_profit WHERE user_id = '7A9637') as total_referral_profit,
    (SELECT available_usdt FROM affiliate_cycle WHERE user_id = '7A9637') as available_usdt;

-- ========================================
-- 9. 日付別の合計（個人利益 + 紹介報酬）
-- ========================================
SELECT
    COALESCE(ndp.date, urp.date) as date,
    COALESCE(SUM(ndp.daily_profit), 0) as personal_profit,
    COALESCE(SUM(urp.profit_amount), 0) as referral_profit,
    COALESCE(SUM(ndp.daily_profit), 0) + COALESCE(SUM(urp.profit_amount), 0) as total_profit
FROM (
    SELECT date, SUM(daily_profit) as daily_profit
    FROM nft_daily_profit
    WHERE user_id = '7A9637'
    GROUP BY date
) ndp
FULL OUTER JOIN (
    SELECT date, SUM(profit_amount) as profit_amount
    FROM user_referral_profit
    WHERE user_id = '7A9637'
    GROUP BY date
) urp ON ndp.date = urp.date
ORDER BY COALESCE(ndp.date, urp.date) DESC
LIMIT 10;
