-- ========================================
-- 日利処理の実際の実行（テストモード）
-- 運用開始済みユーザーに対して利益を発生させる
-- ========================================

-- 1. 2025年7月17日の日利処理を実行（今日）
SELECT * FROM process_daily_yield_with_cycles(
    '2025-07-17'::date,    -- 今日の日付
    0.016,                 -- 1.6%の日利
    30,                    -- 30%マージン
    true,                  -- テストモード
    false                  -- 月末処理ではない
);

-- 2. 結果確認：作成されたuser_daily_profitデータ
SELECT 
    '=== 作成された日利データ ===' as info,
    user_id,
    date,
    daily_profit,
    base_amount,
    yield_rate,
    user_rate,
    phase
FROM user_daily_profit
WHERE date = '2025-07-17'
ORDER BY daily_profit DESC;

-- 3. affiliate_cycleの更新状況確認
SELECT 
    '=== 更新されたサイクル状況 ===' as info,
    user_id,
    cum_usdt,
    available_usdt,
    phase,
    next_action,
    total_nft_count
FROM affiliate_cycle
WHERE user_id IN (
    SELECT DISTINCT user_id 
    FROM user_daily_profit 
    WHERE date = '2025-07-17'
)
ORDER BY cum_usdt DESC;

-- 4. 日利設定ログ確認
SELECT 
    '=== 日利設定ログ ===' as info,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date = '2025-07-17';

-- 5. 運用開始済みユーザーの利益合計
SELECT 
    '=== 本日の利益合計 ===' as info,
    COUNT(*) as processed_users,
    SUM(daily_profit) as total_daily_profit,
    AVG(daily_profit) as avg_daily_profit,
    MAX(daily_profit) as max_daily_profit
FROM user_daily_profit
WHERE date = '2025-07-17';

-- 6. 個別ユーザー確認（7A9637）
SELECT 
    '=== User 7A9637 詳細 ===' as info,
    udp.user_id,
    udp.daily_profit,
    udp.base_amount,
    ac.total_nft_count,
    u.total_purchases
FROM user_daily_profit udp
JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
JOIN users u ON udp.user_id = u.user_id
WHERE udp.user_id = '7A9637' 
AND udp.date = '2025-07-17';