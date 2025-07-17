-- ========================================
-- 🚨 3000%異常値の修正
-- 7/10のマージン率を30%に修正
-- ========================================

-- STEP 1: 現在の異常値確認
SELECT 
    '=== 異常値の確認 ===' as status,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent,
    created_at
FROM daily_yield_log
WHERE date = '2025-07-10';

-- STEP 2: 正しい値で再計算
-- yield_rate: 0.0085 (0.85%)
-- margin_rate: 0.30 (30%) <- 3000%を30%に修正
-- user_rate: 0.0085 * (1 - 0.30) * 0.6 = 0.00357 (0.357%)

-- STEP 3: daily_yield_logの修正
UPDATE daily_yield_log
SET 
    margin_rate = 0.30,  -- 30%に修正
    user_rate = 0.00357  -- 再計算した値
WHERE date = '2025-07-10';

-- STEP 4: user_daily_profitの再計算
-- 既存データが間違っている可能性があるため削除して再作成
DELETE FROM user_daily_profit WHERE date = '2025-07-10';

-- STEP 5: 正しい値で再作成
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
    '2025-07-10' as date,
    (ac.total_nft_count * 1100 * 0.00357) as daily_profit,
    0.0085 as yield_rate,
    0.00357 as user_rate,
    (ac.total_nft_count * 1100) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase,
    '2025-07-10 16:00:00+00' as created_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0;

-- STEP 6: 修正後の確認
SELECT 
    '=== 修正後の日利設定 ===' as fixed_status,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent
FROM daily_yield_log
WHERE date = '2025-07-10';

-- STEP 7: 修正後のuser_daily_profit確認
SELECT 
    '=== 修正後の利益データ ===' as profit_status,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit
FROM user_daily_profit
WHERE date = '2025-07-10';

-- STEP 8: 特定ユーザー（7A9637）の確認
SELECT 
    '=== 7A9637の7/10データ ===' as user_check,
    user_id,
    date,
    daily_profit,
    user_rate * 100 as user_rate_percent,
    base_amount
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-07-10';