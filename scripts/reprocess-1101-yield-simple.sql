-- 11/1の日利を再計算（シンプル版）
-- 実行前に現在のデータを確認してから削除・再計算します

-- ===== STEP 1: 現在のデータを確認 =====
SELECT '現在の日利設定' as step;
SELECT date, yield_rate, margin_rate, user_rate
FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '現在の個人利益（合計）' as step;
SELECT COUNT(*) as users, SUM(daily_profit) as total
FROM user_daily_profit WHERE date = '2025-11-01';

SELECT '現在の紹介報酬（合計）' as step;
SELECT COUNT(*) as rewards, SUM(profit_amount) as total
FROM user_referral_profit WHERE date = '2025-11-01';

-- ===== STEP 2: 古いデータを削除 =====
DELETE FROM user_referral_profit WHERE date = '2025-11-01';
DELETE FROM user_daily_profit WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-01';

-- ===== STEP 3: 正しい値で再計算 =====
SELECT process_daily_yield_with_cycles(
    '2025-11-01'::DATE,
    -0.02::NUMERIC,
    30.0::NUMERIC,
    FALSE,
    FALSE
);

-- ===== STEP 4: 修正後のデータを確認 =====
SELECT '修正後の日利設定' as step;
SELECT date, yield_rate, margin_rate, user_rate
FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '修正後の個人利益（合計）' as step;
SELECT COUNT(*) as users, SUM(daily_profit) as total
FROM user_daily_profit WHERE date = '2025-11-01';

SELECT '修正後の紹介報酬（合計）' as step;
SELECT COUNT(*) as rewards, SUM(profit_amount) as total
FROM user_referral_profit WHERE date = '2025-11-01';

SELECT '✅ 完了' as status;
