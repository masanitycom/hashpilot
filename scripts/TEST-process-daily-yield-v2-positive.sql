-- ========================================
-- process_daily_yield_v2 テスト実行（プラス日利）
-- 紹介報酬とNFT自動付与の動作確認
-- ========================================

-- テスト日付: 2025-11-11 (+$1580.32)
-- テストモードで実行（既存データ削除して再計算）

-- ========================================
-- Step 1: 実行前の状態を確認
-- ========================================
SELECT '=== 実行前の状態 ===' as section;

-- ユーザー7A9637の紹介ツリー確認
SELECT
    '7A9637の直接紹介者（Level 1）' as label,
    u.user_id,
    u.full_name,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.referrer_user_id = '7A9637'
GROUP BY u.user_id, u.full_name, u.has_approved_nft, u.operation_start_date
ORDER BY u.user_id;

-- Level 1の2025-11-11の日利を確認
SELECT
    '7A9637のLevel 1紹介者の日利' as label,
    u.user_id,
    u.full_name,
    COALESCE(SUM(ndp.daily_profit), 0) as daily_profit_2025_11_11
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id AND ndp.date = '2025-11-11'
WHERE u.referrer_user_id = '7A9637'
    AND u.has_approved_nft = true
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= '2025-11-11'
GROUP BY u.user_id, u.full_name
HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
ORDER BY u.user_id;

-- ========================================
-- Step 2: テストモードで再計算実行
-- ========================================
SELECT '=== テスト実行 ===' as section;

SELECT * FROM process_daily_yield_v2(
    '2025-11-11'::DATE,
    1580.32::NUMERIC,
    TRUE  -- テストモード（既存データ削除）
);

-- ========================================
-- Step 3: 実行後の結果を確認
-- ========================================
SELECT '=== 実行後の結果 ===' as section;

-- 日利ログ
SELECT
    '日利ログ' as label,
    date,
    total_profit_amount,
    total_nft_count,
    daily_pnl,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock
FROM daily_yield_log_v2
WHERE date = '2025-11-11';

-- ユーザー7A9637の個人利益
SELECT
    '7A9637の個人利益' as label,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_personal_profit
FROM nft_daily_profit
WHERE user_id = '7A9637' AND date = '2025-11-11'
GROUP BY date;

-- ユーザー7A9637の紹介報酬（レベル別）
SELECT
    '7A9637の紹介報酬（レベル別）' as label,
    referral_level,
    COUNT(*) as count,
    SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE user_id = '7A9637' AND date = '2025-11-11'
GROUP BY referral_level
ORDER BY referral_level;

-- 紹介報酬の詳細
SELECT
    '7A9637の紹介報酬詳細' as label,
    urp.referral_level,
    urp.child_user_id,
    u.full_name as child_name,
    urp.profit_amount,
    (SELECT SUM(daily_profit) FROM nft_daily_profit WHERE user_id = urp.child_user_id AND date = '2025-11-11') as child_daily_profit,
    (urp.profit_amount / NULLIF((SELECT SUM(daily_profit) FROM nft_daily_profit WHERE user_id = urp.child_user_id AND date = '2025-11-11'), 0)) as reward_rate
FROM user_referral_profit urp
JOIN users u ON urp.child_user_id = u.user_id
WHERE urp.user_id = '7A9637' AND urp.date = '2025-11-11'
ORDER BY urp.referral_level, urp.profit_amount DESC;

-- ユーザー7A9637のaffiliate_cycle更新確認
SELECT
    '7A9637のaffiliate_cycle' as label,
    cum_usdt,
    available_usdt,
    auto_nft_count,
    total_nft_count,
    phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- ========================================
-- Step 4: 全体の紹介報酬サマリー
-- ========================================
SELECT '=== 紹介報酬サマリー ===' as section;

-- レベル別の紹介報酬
SELECT
    referral_level,
    COUNT(DISTINCT user_id) as receiver_count,
    COUNT(*) as total_records,
    SUM(profit_amount) as total_amount,
    AVG(profit_amount) as avg_amount,
    MIN(profit_amount) as min_amount,
    MAX(profit_amount) as max_amount
FROM user_referral_profit
WHERE date = '2025-11-11'
GROUP BY referral_level
ORDER BY referral_level;

-- 紹介報酬を受け取ったユーザーTOP10
SELECT
    'TOP10紹介報酬受取者' as label,
    urp.user_id,
    u.full_name,
    SUM(urp.profit_amount) as total_referral_profit,
    SUM(CASE WHEN urp.referral_level = 1 THEN urp.profit_amount ELSE 0 END) as level1,
    SUM(CASE WHEN urp.referral_level = 2 THEN urp.profit_amount ELSE 0 END) as level2,
    SUM(CASE WHEN urp.referral_level = 3 THEN urp.profit_amount ELSE 0 END) as level3
FROM user_referral_profit urp
JOIN users u ON urp.user_id = u.user_id
WHERE urp.date = '2025-11-11'
GROUP BY urp.user_id, u.full_name
ORDER BY total_referral_profit DESC
LIMIT 10;

-- ========================================
-- Step 5: NFT自動付与の確認
-- ========================================
SELECT '=== NFT自動付与の確認 ===' as section;

-- cum_usdt >= 2200のユーザー（自動付与対象）
SELECT
    'cum_usdt >= 2200のユーザー' as label,
    u.user_id,
    u.full_name,
    ac.cum_usdt,
    ac.auto_nft_count,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'auto' AND nm.acquired_date = '2025-11-11') as new_auto_nft_today
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id
WHERE ac.cum_usdt >= 1000
GROUP BY u.user_id, u.full_name, ac.cum_usdt, ac.auto_nft_count
ORDER BY ac.cum_usdt DESC
LIMIT 20;

-- ========================================
-- Step 6: 全体サマリー
-- ========================================
SELECT '=== 全体サマリー ===' as section;

-- 配布された合計
SELECT
    '個人利益配布' as category,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_amount
FROM nft_daily_profit
WHERE date = '2025-11-11'
UNION ALL
SELECT
    '紹介報酬配布' as category,
    COUNT(DISTINCT user_id) as user_count,
    SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date = '2025-11-11'
UNION ALL
SELECT
    'ストック配布' as category,
    COUNT(DISTINCT user_id) as user_count,
    SUM(stock_amount) as total_amount
FROM stock_fund
WHERE date = '2025-11-11';

-- 完了
SELECT '=== テスト完了 ===' as section;
