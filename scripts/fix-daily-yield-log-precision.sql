-- daily_yield_logテーブルの数値型精度を修正

-- 1. テーブル構造を確認
SELECT '=== daily_yield_logテーブル構造確認 ===' as section;
SELECT 
    column_name, 
    data_type, 
    numeric_precision,
    numeric_scale,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
AND column_name IN ('yield_rate', 'margin_rate', 'user_rate')
ORDER BY ordinal_position;

-- 2. 数値型の精度を拡張
ALTER TABLE daily_yield_log 
ALTER COLUMN yield_rate TYPE NUMERIC(10,6);

ALTER TABLE daily_yield_log 
ALTER COLUMN user_rate TYPE NUMERIC(10,6);

-- margin_rateはそのまま（30以下なので問題なし）

-- 3. 修正後の構造確認
SELECT '=== 修正後のテーブル構造 ===' as section;
SELECT 
    column_name, 
    data_type, 
    numeric_precision,
    numeric_scale,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
AND column_name IN ('yield_rate', 'margin_rate', 'user_rate')
ORDER BY ordinal_position;

-- 4. 正しい日利率で7/10を再設定
DELETE FROM user_daily_profit WHERE date = '2025-07-10';

-- 5. 修正された関数で再実行
SELECT process_daily_yield_with_cycles(
    '2025-07-10'::DATE,
    0.0138,  -- 1.38%
    30,      -- 30%マージン  
    false    -- 本番モード
);

-- 6. 結果確認
SELECT '=== 修正後の利益確認 ===' as section;
SELECT 
    u.user_id,
    u.total_purchases,
    ac.total_nft_count,
    udp.personal_profit,
    udp.referral_profit,
    udp.daily_profit as total_profit,
    -- 期待値: NFT数 × 1000 × 0.005796
    (ac.total_nft_count * 1000 * 0.005796) as expected_personal_profit,
    CASE 
        WHEN abs(udp.personal_profit - (ac.total_nft_count * 1000 * 0.005796)) < 0.01 
        THEN 'OK' 
        ELSE 'MISMATCH' 
    END as status
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-10'
WHERE u.user_id IN ('2BF53B', '9DCFD1', 'B43A3D')
ORDER BY u.total_purchases DESC;

-- 7. daily_yield_logの確認
SELECT '=== daily_yield_log確認 ===' as section;
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate
FROM daily_yield_log
WHERE date = '2025-07-10';

SELECT 'daily_yield_logテーブルの精度を修正し、正しい日利率で再計算しました' as message;