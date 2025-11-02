-- daily_yieldsテーブルの数値カラムに明示的な精度を設定（必要な場合のみ実行）
-- NUMERIC(10,3) = 小数点第3位まで（1.000%形式）

-- 注意: このスクリプトは既存データに影響を与えません
-- 既にNUMERIC型で十分な精度がある場合は実行不要

-- yield_rate: -10.000% ～ 100.000% の範囲
ALTER TABLE daily_yields
ALTER COLUMN yield_rate TYPE NUMERIC(10,3);

-- margin_rate: 0.000% ～ 100.000% の範囲
ALTER TABLE daily_yields
ALTER COLUMN margin_rate TYPE NUMERIC(10,3);

-- user_rate: 計算結果、-10.000% ～ 100.000% の範囲
ALTER TABLE daily_yields
ALTER COLUMN user_rate TYPE NUMERIC(10,3);

-- 確認
SELECT
    column_name,
    data_type,
    numeric_precision,
    numeric_scale
FROM information_schema.columns
WHERE table_name = 'daily_yields'
AND column_name IN ('yield_rate', 'margin_rate', 'user_rate')
ORDER BY column_name;
