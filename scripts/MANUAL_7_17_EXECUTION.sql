-- 🚨 7/17の手動実行
-- 2025年7月17日

-- 新しい関数を手動で実行（紹介報酬付き）
SELECT * FROM process_daily_yield_with_cycles(
    '2025-07-17'::date,
    0.0015,      -- 日利率1.5%
    30,          -- マージン率30%
    false,       -- 本番モード
    false        -- 月末処理ではない
);

-- 実行結果確認
SELECT 
    '7/17手動実行結果' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE date = '2025-07-17'
ORDER BY created_at DESC;

-- システムログ確認
SELECT 
    '7/17システムログ確認' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%daily_yield%'
AND DATE(created_at) = '2025-07-17'
ORDER BY created_at DESC;