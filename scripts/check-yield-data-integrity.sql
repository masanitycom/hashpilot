-- ========================================
-- 日利データの整合性確認
-- ========================================

-- 1. daily_yield_log_v2の最新データ（直近10日分）
SELECT
    '1. daily_yield_log_v2 最新データ' as section,
    date,
    total_profit_amount,
    total_nft_count,
    cumulative_gross_profit,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    distribution_dividend
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- 2. 2025/11/9のデータ詳細
SELECT
    '2. 2025/11/9のデータ詳細' as section,
    *
FROM daily_yield_log_v2
WHERE date = '2025-11-09';

-- 3. nft_daily_profit（2025/11/9）のユーザーごと集計
SELECT
    '3. nft_daily_profit (2025/11/9)' as section,
    user_id,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date = '2025-11-09'
GROUP BY user_id
ORDER BY total_profit DESC
LIMIT 20;

-- 4. user_daily_profit VIEW（2025/11/9）
SELECT
    '4. user_daily_profit VIEW (2025/11/9)' as section,
    user_id,
    daily_profit,
    yield_rate,
    created_at
FROM user_daily_profit
WHERE date = '2025-11-09'
ORDER BY daily_profit DESC
LIMIT 20;

-- 5. 累積計算の履歴
SELECT
    '5. 累積計算の履歴（直近10日）' as section,
    date,
    total_profit_amount as input_amount,
    cumulative_gross_profit as G_d,
    cumulative_fee as F_d,
    cumulative_net_profit as N_d,
    daily_pnl as delta_N_d,
    CASE
        WHEN daily_pnl > 0 THEN '✅ プラス配当あり'
        WHEN daily_pnl = 0 THEN '⚠️ ゼロ'
        ELSE '❌ マイナス・配当なし'
    END as status
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- 6. ユーザーが0件の場合の確認
SELECT
    '6. nft_daily_profit レコード数確認' as section,
    date,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as unique_users
FROM nft_daily_profit
WHERE date >= '2025-11-01'
GROUP BY date
ORDER BY date DESC;

-- 7. 特定ユーザーの利益履歴（サンプル）
SELECT
    '7. サンプルユーザーの利益履歴' as section,
    date,
    daily_profit,
    yield_rate
FROM user_daily_profit
WHERE user_id = (SELECT user_id FROM users WHERE has_approved_nft = true LIMIT 1)
    AND date >= '2025-11-01'
ORDER BY date DESC;
