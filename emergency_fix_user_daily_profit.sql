-- ========================================
-- 🚨 緊急修正: user_daily_profitテーブル問題解決
-- 日利表示が16日1日分しか出ない問題の修正
-- ========================================

-- STEP 1: RLSポリシー修正（フロントエンドアクセス許可）
DROP POLICY IF EXISTS "anon_users_read_daily_profit" ON user_daily_profit;
DROP POLICY IF EXISTS "allow_frontend_access" ON user_daily_profit;

CREATE POLICY "allow_frontend_access" ON user_daily_profit
    FOR SELECT
    TO public
    USING (true);

-- STEP 2: 現在の状況確認
SELECT 
    '=== 現在のuser_daily_profit状況 ===' as status,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM user_daily_profit;

-- STEP 3: 設定済み日利確認
SELECT 
    '=== 管理画面で設定済みの日利 ===' as yield_settings,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent,
    created_at
FROM daily_yield_log
ORDER BY date DESC;

-- STEP 4: 対象ユーザー確認
SELECT 
    '=== 利益配布対象ユーザー ===' as target_users,
    COUNT(*) as total_users,
    SUM(ac.total_nft_count) as total_nft,
    SUM(ac.total_nft_count * 1100) as total_investment
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0;

-- STEP 5: 管理画面設定を使用した過去の利益データ作成
-- 7/15の日利設定を使用
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase,
    created_at
)
SELECT 
    ac.user_id,
    '2025-07-15' as date,
    (ac.total_nft_count * 1100 * yl.user_rate) as daily_profit,
    yl.yield_rate,
    yl.user_rate,
    (ac.total_nft_count * 1100) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase,
    '2025-07-15 16:00:00+00' as created_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
CROSS JOIN (
    SELECT yield_rate, user_rate 
    FROM daily_yield_log 
    WHERE date = '2025-07-15'
    LIMIT 1
) yl
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase;

-- 7/14の日利設定を使用
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase,
    created_at
)
SELECT 
    ac.user_id,
    '2025-07-14' as date,
    (ac.total_nft_count * 1100 * yl.user_rate) as daily_profit,
    yl.yield_rate,
    yl.user_rate,
    (ac.total_nft_count * 1100) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase,
    '2025-07-14 16:00:00+00' as created_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
CROSS JOIN (
    SELECT yield_rate, user_rate 
    FROM daily_yield_log 
    WHERE date = '2025-07-14'
    LIMIT 1
) yl
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase;

-- 7/13の日利設定を使用
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase,
    created_at
)
SELECT 
    ac.user_id,
    '2025-07-13' as date,
    (ac.total_nft_count * 1100 * yl.user_rate) as daily_profit,
    yl.yield_rate,
    yl.user_rate,
    (ac.total_nft_count * 1100) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase,
    '2025-07-13 16:00:00+00' as created_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
CROSS JOIN (
    SELECT yield_rate, user_rate 
    FROM daily_yield_log 
    WHERE date = '2025-07-13'
    LIMIT 1
) yl
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase;

-- STEP 6: 修正後の確認
SELECT 
    '=== 修正後のuser_daily_profit ===' as fixed_status,
    date,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit,
    AVG(user_rate * 100) as avg_user_rate_percent
FROM user_daily_profit
GROUP BY date
ORDER BY date DESC;

-- STEP 7: 特定ユーザーの確認（7A9637など）
SELECT 
    '=== 特定ユーザーの日利履歴 ===' as user_history,
    user_id,
    date,
    daily_profit,
    user_rate * 100 as user_rate_percent,
    base_amount
FROM user_daily_profit
WHERE user_id IN (
    SELECT user_id 
    FROM affiliate_cycle 
    WHERE total_nft_count > 0 
    LIMIT 3
)
ORDER BY user_id, date DESC;

-- STEP 8: ダッシュボード用データ確認
SELECT 
    '=== ダッシュボード用最新データ ===' as dashboard_data,
    COUNT(DISTINCT user_id) as active_users,
    SUM(daily_profit) as total_distributed,
    MIN(date) as data_start_date,
    MAX(date) as data_end_date
FROM user_daily_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days';