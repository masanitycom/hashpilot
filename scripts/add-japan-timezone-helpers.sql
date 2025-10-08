-- ========================================
-- 日本時間ヘルパー関数
-- すべての日付処理を日本時間（JST）で統一
-- ========================================

-- 1. 現在の日本時間の日付を取得
CREATE OR REPLACE FUNCTION get_japan_date()
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;
$$;

-- 2. 現在の日本時間のタイムスタンプを取得
CREATE OR REPLACE FUNCTION get_japan_now()
RETURNS TIMESTAMP
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NOW() AT TIME ZONE 'Asia/Tokyo';
$$;

-- 3. 指定月の最初の日を取得（日本時間）
CREATE OR REPLACE FUNCTION get_month_start(p_date DATE)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT DATE_TRUNC('month', p_date)::DATE;
$$;

-- 4. 指定月の最後の日を取得（日本時間）
CREATE OR REPLACE FUNCTION get_month_end(p_date DATE)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT (DATE_TRUNC('month', p_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
$$;

-- 5. 今日が月末かどうか判定（日本時間）
CREATE OR REPLACE FUNCTION is_month_end()
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT get_japan_date() = get_month_end(get_japan_date());
$$;

-- 6. 今日が月初かどうか判定（日本時間）
CREATE OR REPLACE FUNCTION is_month_start()
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT get_japan_date() = get_month_start(get_japan_date());
$$;

-- 7. 年月を取得（日本時間）
CREATE OR REPLACE FUNCTION get_japan_year_month()
RETURNS TABLE(year INTEGER, month INTEGER)
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT
        EXTRACT(YEAR FROM get_japan_date())::INTEGER,
        EXTRACT(MONTH FROM get_japan_date())::INTEGER;
$$;

-- テスト実行
DO $$
DECLARE
    v_date DATE;
    v_now TIMESTAMP;
    v_month_start DATE;
    v_month_end DATE;
    v_is_month_end BOOLEAN;
    v_is_month_start BOOLEAN;
BEGIN
    v_date := get_japan_date();
    v_now := get_japan_now();
    v_month_start := get_month_start(v_date);
    v_month_end := get_month_end(v_date);
    v_is_month_end := is_month_end();
    v_is_month_start := is_month_start();

    RAISE NOTICE '===========================================';
    RAISE NOTICE '日本時間ヘルパー関数のテスト結果';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '現在の日本時間（日付）: %', v_date;
    RAISE NOTICE '現在の日本時間（時刻）: %', v_now;
    RAISE NOTICE '今月の開始日: %', v_month_start;
    RAISE NOTICE '今月の最終日: %', v_month_end;
    RAISE NOTICE '今日は月末？: %', v_is_month_end;
    RAISE NOTICE '今日は月初？: %', v_is_month_start;
    RAISE NOTICE '===========================================';
END $$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_japan_date() TO authenticated;
GRANT EXECUTE ON FUNCTION get_japan_date() TO anon;
GRANT EXECUTE ON FUNCTION get_japan_now() TO authenticated;
GRANT EXECUTE ON FUNCTION get_japan_now() TO anon;
GRANT EXECUTE ON FUNCTION get_month_start(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_month_start(DATE) TO anon;
GRANT EXECUTE ON FUNCTION get_month_end(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_month_end(DATE) TO anon;
GRANT EXECUTE ON FUNCTION is_month_end() TO authenticated;
GRANT EXECUTE ON FUNCTION is_month_end() TO anon;
GRANT EXECUTE ON FUNCTION is_month_start() TO authenticated;
GRANT EXECUTE ON FUNCTION is_month_start() TO anon;
GRANT EXECUTE ON FUNCTION get_japan_year_month() TO authenticated;
GRANT EXECUTE ON FUNCTION get_japan_year_month() TO anon;

SELECT '✅ 日本時間ヘルパー関数を作成しました' as status;
