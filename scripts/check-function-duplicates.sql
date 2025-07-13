-- process_daily_yield_with_cycles関数の重複を調査するスクリプト

-- 1. 現在存在する関数のバージョンをすべて確認
SELECT 
    p.proname,
    p.pronargs as arg_count,
    p.proargnames as arg_names,
    format_type(p.prorettype, NULL) as return_type,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as result_type
FROM pg_proc p
WHERE p.proname = 'process_daily_yield_with_cycles'
ORDER BY p.pronargs;

-- 2. 詳細な関数シグネチャを確認
SELECT 
    p.oid,
    p.proname,
    p.pronargs,
    array_to_string(
        ARRAY(
            SELECT format_type(unnest(p.proargtypes), NULL)
        ), 
        ', '
    ) as argument_types,
    p.proargnames,
    p.prosrc LIKE '%p_is_month_end%' as has_month_end_param
FROM pg_proc p
WHERE p.proname = 'process_daily_yield_with_cycles'
ORDER BY p.pronargs, p.oid;

-- 3. 最後に作成された関数を特定
SELECT 
    p.oid,
    p.proname,
    p.pronargs,
    pg_get_function_arguments(p.oid) as full_signature,
    CASE 
        WHEN p.prosrc LIKE '%p_is_month_end%' THEN '5引数版（月末対応）'
        ELSE '4引数版（標準）'
    END as version_type
FROM pg_proc p
WHERE p.proname = 'process_daily_yield_with_cycles'
ORDER BY p.oid DESC;