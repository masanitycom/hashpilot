-- daily_yieldsテーブルの数値カラムの精度を確認
SELECT
    column_name,
    data_type,
    numeric_precision,
    numeric_scale,
    CASE
        WHEN numeric_scale IS NULL THEN 'unlimited precision'
        ELSE 'precision: ' || numeric_precision || ', scale: ' || numeric_scale
    END as precision_info
FROM information_schema.columns
WHERE table_name = 'daily_yields'
AND column_name IN ('yield_rate', 'margin_rate', 'user_rate')
ORDER BY column_name;

-- テスト: 小数点第3位まで保存できるか確認
DO $$
DECLARE
    test_yield NUMERIC;
BEGIN
    -- 1.234% のような値を保存できるかテスト
    test_yield := 1.234;
    RAISE NOTICE 'Test value: %', test_yield;
    RAISE NOTICE 'Small decimal test (0.001): %', 0.001::NUMERIC;
    RAISE NOTICE 'Three decimal places (1.234): %', 1.234::NUMERIC;
END $$;
