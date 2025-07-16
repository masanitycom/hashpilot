-- 🔧 グラフの日利率表示を修正
-- 2025年7月17日

-- 問題: グラフがuser_daily_profitのuser_rateを使用（四捨五入された値）
-- 解決: daily_yield_logテーブルから正確な管理画面設定値を取得

-- 1. 現在の問題を確認
SELECT 
    'problem_confirmation' as check_type,
    udp.date,
    udp.user_rate as stored_user_rate,
    dyl.user_rate as admin_set_user_rate,
    dyl.yield_rate as admin_set_yield_rate,
    dyl.margin_rate as admin_set_margin_rate
FROM user_daily_profit udp
LEFT JOIN daily_yield_log dyl ON udp.date = dyl.date
WHERE udp.user_id = '7A9637'
AND udp.date >= '2025-07-11'
ORDER BY udp.date DESC;

-- 2. 正しい値の検証
SELECT 
    'correct_values' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    -- パーセンテージ表示での確認
    (yield_rate * 100) as yield_rate_percent,
    (margin_rate * 100) as margin_rate_percent,
    (user_rate * 100) as user_rate_percent
FROM daily_yield_log
WHERE date >= '2025-07-11'
ORDER BY date DESC;