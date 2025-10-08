-- process_buyback_request関数の存在確認

SELECT
    '=== process_buyback_request関数の確認 ===' as section,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'process_buyback_request';

-- 買い取り関連の全関数を確認
SELECT
    '=== 買い取り関連の全関数 ===' as section,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname LIKE '%buyback%'
ORDER BY proname;
