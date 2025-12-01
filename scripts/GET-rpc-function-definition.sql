-- ========================================
-- RPC関数の定義を取得
-- ========================================

-- process_daily_yield_v2の定義
SELECT 
    'process_daily_yield_v2' as function_name,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';

-- process_daily_yield_with_cyclesの定義
SELECT 
    'process_daily_yield_with_cycles' as function_name,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';

