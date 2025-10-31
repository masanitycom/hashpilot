-- 現在の approve_user_nft 関数の定義を確認
SELECT
    proname as function_name,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'approve_user_nft';
