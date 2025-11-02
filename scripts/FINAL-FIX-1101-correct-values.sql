-- 11/1のデータを完全に削除して、正しい値で再計算
-- yield_rate: -0.02（パーセント値、つまり-0.02%）

-- ===== STEP 1: 現在のデータ確認 =====
SELECT '【削除前】yield_rate確認' as step;
SELECT yield_rate, user_rate FROM daily_yield_log WHERE date = '2025-11-01';

-- ===== STEP 2: 完全削除 =====
DELETE FROM user_referral_profit WHERE date = '2025-11-01';
DELETE FROM nft_daily_profit WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '【削除完了】' as step;

-- ===== STEP 3: 正しい値で再計算 =====
-- yield_rate: -0.02 = -0.02%
-- RPC関数内で /100 されるので、-0.0002の割合になる
-- user_rate: -0.0002 × 0.7 × 0.6 = -0.000084

SELECT '【再計算開始】' as step;
SELECT * FROM process_daily_yield_with_cycles(
    '2025-11-01'::DATE,
    -0.02::NUMERIC,  -- -0.02%
    30.0::NUMERIC,
    FALSE,
    FALSE
);

-- ===== STEP 4: 結果確認 =====
SELECT '【修正後】yield_rate確認（期待値: -0.02）' as step;
SELECT
    yield_rate as "yield_rate（期待値: -0.02）",
    user_rate as "user_rate（期待値: -0.000084）"
FROM daily_yield_log
WHERE date = '2025-11-01';

SELECT '【個人利益サンプル】' as step;
SELECT user_id, daily_profit
FROM nft_daily_profit
WHERE date = '2025-11-01'
LIMIT 3;

SELECT '【紹介報酬サンプル】' as step;
SELECT user_id, profit_amount
FROM user_referral_profit
WHERE date = '2025-11-01'
LIMIT 3;

SELECT '✅ 完了' as status;
