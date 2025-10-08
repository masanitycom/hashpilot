-- 現在のapprove_user_nft関数の定義を確認

SELECT
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'approve_user_nft';
