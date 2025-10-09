-- 7E0A1Eのmanual_nft_countを修正
-- クリーンアップ前に必ず実行すること！

-- 現在の状態確認
SELECT
    user_id,
    email,
    total_purchases,
    FLOOR(total_purchases / 1100) as expected_nft
FROM users
WHERE user_id = '7E0A1E';

SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- manual_nft_countを修正
UPDATE affiliate_cycle
SET
    manual_nft_count = FLOOR((
        SELECT total_purchases FROM users WHERE user_id = '7E0A1E'
    ) / 1100),
    last_updated = NOW()
WHERE user_id = '7E0A1E';

-- 修正後の確認
SELECT
    ac.user_id,
    u.email,
    u.total_purchases,
    ac.manual_nft_count,
    ac.total_nft_count,
    ac.auto_nft_count,
    FLOOR(u.total_purchases / 1100) as expected_manual_nft,
    CASE
        WHEN ac.manual_nft_count = FLOOR(u.total_purchases / 1100) THEN '✅ 修正完了'
        ELSE '⚠️ まだ不一致'
    END as status
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id = '7E0A1E';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 7E0A1E のmanual_nft_count修正完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. cleanup-all-test-data-1014.sql を実行';
    RAISE NOTICE '  2. 日利設定でテスト';
    RAISE NOTICE '===========================================';
END $$;
