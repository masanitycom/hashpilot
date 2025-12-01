-- user_daily_profitビューの定義を取得
SELECT 
    pg_get_viewdef('user_daily_profit'::regclass, true) as view_definition;
