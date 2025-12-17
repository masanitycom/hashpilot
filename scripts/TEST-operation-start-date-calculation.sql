-- 運用開始日計算のテスト
-- 1/1と1/15承認のケースを確認

SELECT '【テスト】運用開始日計算' as section;

-- 12月の承認日テスト
SELECT
  '12/3承認' as case_name,
  calculate_operation_start_date('2025-12-03 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 12/15' as expected;

SELECT
  '12/15承認' as case_name,
  calculate_operation_start_date('2025-12-15 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 1/1' as expected;

SELECT
  '12/25承認' as case_name,
  calculate_operation_start_date('2025-12-25 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 1/15' as expected;

-- 1月の承認日テスト
SELECT
  '1/3承認' as case_name,
  calculate_operation_start_date('2026-01-03 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 1/15' as expected;

SELECT
  '1/5承認' as case_name,
  calculate_operation_start_date('2026-01-05 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 1/15' as expected;

SELECT
  '1/6承認' as case_name,
  calculate_operation_start_date('2026-01-06 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 2/1' as expected;

SELECT
  '1/15承認' as case_name,
  calculate_operation_start_date('2026-01-15 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 2/1' as expected;

SELECT
  '1/20承認' as case_name,
  calculate_operation_start_date('2026-01-20 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 2/1' as expected;

SELECT
  '1/21承認' as case_name,
  calculate_operation_start_date('2026-01-21 12:00:00+09'::TIMESTAMPTZ) as operation_start_date,
  '期待: 2/15' as expected;
