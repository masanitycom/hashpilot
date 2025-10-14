-- ========================================
-- 7E0A1Eの個人配当が$0になる原因を調査
-- ========================================

-- 1. affiliate_cycleの現在の状態
SELECT
    '1. affiliate_cycle' as section,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 2. 実際のNFT数
SELECT
    '2. 実際のNFT数' as section,
    COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_active,
    COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as auto_active,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_active
FROM nft_master
WHERE user_id = '7E0A1E';

-- 3. nft_daily_profitにデータがあるか
SELECT
    '3. nft_daily_profit' as section,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id = '7E0A1E'
GROUP BY date
ORDER BY date;

-- 4. user_daily_profitビュー
SELECT
    '4. user_daily_profit VIEW' as section,
    date,
    daily_profit
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date;

-- 5. 日利処理ログ
SELECT
    '5. daily_yield_log' as section,
    date,
    yield_rate,
    user_rate
FROM daily_yield_log
ORDER BY date;

-- 6. 7E0A1Eの運用開始日
SELECT
    '6. ユーザー情報' as section,
    user_id,
    has_approved_nft,
    operation_start_date
FROM users
WHERE user_id = '7E0A1E';

-- 7. process_daily_yield_with_cycles関数が最新か確認
SELECT
    '7. 関数の最終更新' as section,
    proname as function_name,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles'
LIMIT 1;
