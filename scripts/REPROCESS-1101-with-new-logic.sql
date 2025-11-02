-- 11/1のデータを新しいロジック（紹介報酬0）で再計算

-- STEP 1: 完全削除
DELETE FROM user_referral_profit WHERE date = '2025-11-01';
DELETE FROM nft_daily_profit WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '削除完了' as status;

-- STEP 2: 再計算（新しいRPC関数を使用）
SELECT * FROM process_daily_yield_with_cycles(
    '2025-11-01'::DATE,
    -0.02::NUMERIC,
    30.0::NUMERIC,
    FALSE,
    FALSE
);

-- STEP 3: 確認
SELECT '【紹介報酬確認】マイナス日利なので0件のはず' as info;
SELECT COUNT(*) as referral_count, COALESCE(SUM(profit_amount), 0) as total
FROM user_referral_profit
WHERE date = '2025-11-01';

SELECT '【個人利益確認】マイナス値が入っているはず' as info;
SELECT COUNT(*) as user_count, SUM(daily_profit) as total
FROM nft_daily_profit
WHERE date = '2025-11-01';

SELECT '✅ 完了' as status;
