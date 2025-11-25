-- user_daily_profitビューの定義を確認

SELECT
    table_name,
    view_definition
FROM information_schema.views
WHERE table_name = 'user_daily_profit';

-- または、PostgreSQL固有のコマンド
-- \d+ user_daily_profit

-- ビューが参照しているテーブルを確認
SELECT DISTINCT
    table_schema,
    table_name
FROM information_schema.view_table_usage
WHERE view_name = 'user_daily_profit';
