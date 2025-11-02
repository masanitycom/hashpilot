-- 11/1データ修正：最終版（最もシンプル）

-- ===== STEP 1: 現在の値を確認 =====
SELECT '【確認】現在の11/1データ' as info;
SELECT date, yield_rate, user_rate FROM daily_yield_log WHERE date = '2025-11-01';

-- ===== STEP 2: 削除 =====
DELETE FROM user_referral_profit WHERE date = '2025-11-01';
DELETE FROM user_daily_profit WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '【削除完了】' as info;

-- ===== STEP 3: 再計算 =====
SELECT '【再計算開始】-0.02% で処理' as info;

SELECT * FROM process_daily_yield_with_cycles(
    '2025-11-01'::DATE,
    -0.02::NUMERIC,
    30.0::NUMERIC,
    FALSE,
    FALSE
);

-- ===== STEP 4: 結果確認 =====
SELECT '【完了】修正後のデータ' as info;
SELECT date, yield_rate, user_rate FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '個人利益合計' as info, COUNT(*) as users, SUM(daily_profit) as total
FROM user_daily_profit WHERE date = '2025-11-01';

SELECT '紹介報酬合計' as info, COUNT(*) as records, SUM(profit_amount) as total
FROM user_referral_profit WHERE date = '2025-11-01';
