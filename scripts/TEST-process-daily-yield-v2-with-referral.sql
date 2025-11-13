-- ========================================
-- process_daily_yield_v2 テスト実行
-- 紹介報酬とNFT自動付与の動作確認
-- ========================================

-- テスト日付: 2025-11-12 (既存データを再計算)
-- テストモードで実行（既存データ削除して再計算）

-- ========================================
-- Step 1: 実行前の状態を確認
-- ========================================
SELECT '=== 実行前の状態 ===' as section;

-- 2025-11-12の日利ログ
SELECT
    date,
    total_profit_amount,
    total_nft_count,
    daily_pnl,
    distribution_dividend
FROM daily_yield_log_v2
WHERE date = '2025-11-12';

-- ユーザー7A9637の現在の状態
SELECT
    '7A9637の個人利益' as label,
    COALESCE(SUM(daily_profit), 0) as total_personal_profit
FROM nft_daily_profit
WHERE user_id = '7A9637' AND date = '2025-11-12';

SELECT
    '7A9637の紹介報酬' as label,
    COALESCE(SUM(profit_amount), 0) as total_referral_profit,
    COUNT(*) as referral_count
FROM user_referral_profit
WHERE user_id = '7A9637' AND date = '2025-11-12';

SELECT
    '7A9637のaffiliate_cycle' as label,
    cum_usdt,
    available_usdt,
    auto_nft_count,
    phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- ========================================
-- Step 2: テストモードで再計算実行
-- ========================================
SELECT '=== テスト実行 ===' as section;

SELECT * FROM process_daily_yield_v2(
    '2025-11-12'::DATE,
    -1050.36::NUMERIC,
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
WHERE date = '2025-11-12';

-- ユーザー7A9637の個人利益
SELECT
    '7A9637の個人利益' as label,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_personal_profit
FROM nft_daily_profit
WHERE user_id = '7A9637' AND date = '2025-11-12'
GROUP BY date;

-- ユーザー7A9637の紹介報酬（レベル別）
SELECT
    '7A9637の紹介報酬' as label,
    referral_level,
    COUNT(*) as count,
    SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE user_id = '7A9637' AND date = '2025-11-12'
GROUP BY referral_level
ORDER BY referral_level;

-- 紹介報酬の詳細
SELECT
    '7A9637の紹介報酬詳細' as label,
    urp.referral_level,
    urp.child_user_id,
    u.full_name as child_name,
    urp.profit_amount,
    ndp.daily_profit as child_daily_profit
FROM user_referral_profit urp
JOIN users u ON urp.child_user_id = u.user_id
LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as daily_profit
    FROM nft_daily_profit
    WHERE date = '2025-11-12'
    GROUP BY user_id
) ndp ON urp.child_user_id = ndp.user_id
WHERE urp.user_id = '7A9637' AND urp.date = '2025-11-12'
ORDER BY urp.referral_level, urp.child_user_id;

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
-- Step 4: NFT自動付与の確認
-- ========================================
SELECT '=== NFT自動付与の確認 ===' as section;

-- cum_usdt >= 2200のユーザー
SELECT
    'cum_usdt >= 2200のユーザー' as label,
    u.user_id,
    u.full_name,
    ac.cum_usdt,
    ac.auto_nft_count,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'auto' AND nm.acquired_date = '2025-11-12') as new_auto_nft
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_master nm ON u.user_id = nm.user_id
WHERE ac.cum_usdt >= 1000
GROUP BY u.user_id, u.full_name, ac.cum_usdt, ac.auto_nft_count
ORDER BY ac.cum_usdt DESC;

-- ========================================
-- Step 5: 全体サマリー
-- ========================================
SELECT '=== 全体サマリー ===' as section;

-- 配布された合計
SELECT
    '個人利益配布' as category,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_amount
FROM nft_daily_profit
WHERE date = '2025-11-12'
UNION ALL
SELECT
    '紹介報酬配布' as category,
    COUNT(DISTINCT user_id) as user_count,
    SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date = '2025-11-12'
UNION ALL
SELECT
    'ストック配布' as category,
    COUNT(DISTINCT user_id) as user_count,
    SUM(stock_amount) as total_amount
FROM stock_fund
WHERE date = '2025-11-12';

-- 完了
SELECT '=== テスト完了 ===' as section;
