-- 現在動いている関数のバージョンを確認

SELECT '=== 関数の存在確認 ===' as section;

SELECT
    routine_name,
    routine_type,
    data_type,
    created as last_updated
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles'
  AND routine_schema = 'public';

SELECT '=== 関数の戻り値の列数で判定 ===' as section;

-- 新しい関数は7列返す（referral_rewards_processed列を含む）
-- 古い関数は6列返す

SELECT
    routine_name,
    CASE
        WHEN data_type LIKE '%referral_rewards_processed%'
        THEN '✅ 新バージョン（紹介報酬対応）'
        ELSE '⚠️ 旧バージョン（バグあり）'
    END as version_status
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';

SELECT '=== テスト実行で確認 ===' as section;

-- テストモードで実行して戻り値の列数を確認
SELECT * FROM process_daily_yield_with_cycles(
    CURRENT_DATE,
    0.01,
    30.0,
    true,  -- テストモード
    false
);

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '関数バージョン確認';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '上記の結果を確認してください:';
    RAISE NOTICE '';
    RAISE NOTICE '新バージョンの場合:';
    RAISE NOTICE '  - referral_rewards_processed列がある';
    RAISE NOTICE '  - 7列返る';
    RAISE NOTICE '';
    RAISE NOTICE '旧バージョンの場合:';
    RAISE NOTICE '  - 6列しか返らない';
    RAISE NOTICE '  - add-referral-reward-to-daily-yield.sql';
    RAISE NOTICE '    を再度実行してください';
    RAISE NOTICE '===========================================';
END $$;
