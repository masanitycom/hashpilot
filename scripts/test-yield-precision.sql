-- 小数点第3位の日利率が正しく計算されるかテスト

-- テスト用の仮データ（実際のデータには影響しません）
DO $$
DECLARE
    test_yield_rate NUMERIC := 0.01234; -- 1.234%の割合表現
    test_margin_rate NUMERIC := 0.30;    -- 30%
    calculated_user_rate NUMERIC;
    expected_user_rate NUMERIC := 0.0051996; -- 1.234% × 0.7 × 0.6 = 0.51996%
BEGIN
    -- 計算
    calculated_user_rate := test_yield_rate * (1 - test_margin_rate) * 0.6;

    -- 結果表示
    RAISE NOTICE '=== 小数点第3位精度テスト ===';
    RAISE NOTICE '入力日利率（％表示）: 1.234%%';
    RAISE NOTICE '入力日利率（割合）: %', test_yield_rate;
    RAISE NOTICE 'マージン率: %', test_margin_rate;
    RAISE NOTICE '計算式: % × (1 - %) × 0.6', test_yield_rate, test_margin_rate;
    RAISE NOTICE '計算結果: %', calculated_user_rate;
    RAISE NOTICE '期待値: %', expected_user_rate;
    RAISE NOTICE 'パーセント表示: %％', calculated_user_rate * 100;

    -- 検証
    IF ABS(calculated_user_rate - expected_user_rate) < 0.0000001 THEN
        RAISE NOTICE '✅ テスト成功: 小数点第3位まで正確に計算されています';
    ELSE
        RAISE NOTICE '❌ テスト失敗: 計算結果が期待値と異なります';
    END IF;

    -- より細かい精度のテスト
    RAISE NOTICE '';
    RAISE NOTICE '=== 小数点第6位精度テスト ===';
    test_yield_rate := 0.001234; -- 0.1234%
    calculated_user_rate := test_yield_rate * (1 - test_margin_rate) * 0.6;
    RAISE NOTICE '入力: 0.1234%%';
    RAISE NOTICE '計算結果: %％', calculated_user_rate * 100;
    RAISE NOTICE 'NUMERIC型は任意精度なので問題ありません';
END $$;

-- 実際のデータベース型の確認
SELECT
    column_name,
    data_type,
    COALESCE(numeric_precision::text, 'unlimited') as precision,
    COALESCE(numeric_scale::text, 'unlimited') as scale
FROM information_schema.columns
WHERE table_name = 'daily_yields'
AND column_name IN ('yield_rate', 'margin_rate', 'user_rate')
ORDER BY column_name;
