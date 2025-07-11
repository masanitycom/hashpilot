-- process_daily_yield_with_cycles関数の存在とパラメータを確認

-- 1. 関数の存在確認
SELECT 
    routine_name,
    routine_type,
    specific_name
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 2. 関数のパラメータ詳細を確認
SELECT 
    specific_name,
    parameter_name,
    data_type,
    parameter_mode,
    ordinal_position
FROM information_schema.parameters
WHERE specific_name LIKE '%process_daily_yield_with_cycles%'
ORDER BY ordinal_position;

-- 3. 関数の完全な定義を取得（もし存在すれば）
SELECT 
    pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';

-- 4. 代替関数の確認
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name LIKE '%yield%' OR routine_name LIKE '%daily%'
ORDER BY routine_name;