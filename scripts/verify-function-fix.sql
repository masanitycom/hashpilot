-- 重複修正後の確認スクリプト

-- 1. 修正後の関数確認
SELECT 
    p.proname as function_name,
    p.pronargs as arg_count,
    pg_get_function_arguments(p.oid) as full_signature,
    CASE 
        WHEN p.prosrc LIKE '%p_is_month_end%' THEN '✅ 5引数版（月末対応）'
        ELSE '❌ 4引数版（古い）'
    END as version_type,
    CASE 
        WHEN p.prosrc LIKE '%v_user_rate := v_user_rate \* 1\.05%' THEN '✅ 月末ボーナス対応'
        ELSE '❌ 月末ボーナス未対応'
    END as bonus_support
FROM pg_proc p
WHERE p.proname = 'process_daily_yield_with_cycles'
ORDER BY p.pronargs;

-- 2. 重複チェック
SELECT 
    COUNT(*) as function_count,
    CASE 
        WHEN COUNT(*) = 1 THEN '✅ 重複解消済み'
        WHEN COUNT(*) > 1 THEN '❌ まだ重複あり'
        ELSE '❌ 関数が見つからない'
    END as status
FROM pg_proc p
WHERE p.proname = 'process_daily_yield_with_cycles';

-- 3. 関数の詳細情報
SELECT 
    'process_daily_yield_with_cycles' as function_name,
    p.oid,
    p.pronargs,
    p.proargnames,
    array_to_string(
        ARRAY(
            SELECT format_type(unnest(p.proargtypes), NULL)
        ), 
        ', '
    ) as argument_types,
    LENGTH(p.prosrc) as source_length,
    p.prosrc LIKE '%p_is_month_end%' as has_month_end,
    p.prosrc LIKE '%月末%' as has_japanese_comments
FROM pg_proc p
WHERE p.proname = 'process_daily_yield_with_cycles';

-- 4. テスト実行（ドライラン）
SELECT 'テスト実行準備完了' as message;

-- 実際のテスト実行は管理者が行ってください：
-- SELECT * FROM process_daily_yield_with_cycles('2025-01-11', 0.016, 30, true, false);