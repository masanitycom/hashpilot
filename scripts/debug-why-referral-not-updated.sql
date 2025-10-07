-- なぜ紹介報酬がcum_usdtに反映されないのか調査

SELECT '=== 1. 関数のSTEP 2が実行される条件 ===' as section;

-- STEP 2の条件確認
SELECT
    u.user_id,
    u.email,
    COUNT(ref.user_id) as referral_count,
    COUNT(ref.user_id) FILTER (WHERE ref.has_approved_nft = true) as approved_referral_count
FROM users u
LEFT JOIN users ref ON ref.referrer_user_id = u.user_id
WHERE u.user_id = '7A9637'
GROUP BY u.user_id, u.email;

-- 7A9637がループの対象になるか
SELECT
    '7A9637がSTEP 2のループ対象か' as check_item,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM users ref
            WHERE ref.referrer_user_id = '7A9637'
              AND ref.has_approved_nft = true
        )
        THEN '✅ ループ対象になる'
        ELSE '❌ ループ対象外（紹介者がいない or 未承認）'
    END as result;

SELECT '=== 2. 7E0A1Eの承認状況 ===' as section;

SELECT
    user_id,
    email,
    referrer_user_id,
    has_approved_nft,
    total_purchases
FROM users
WHERE user_id = '7E0A1E';

-- 7E0A1EのNFT確認
SELECT
    COUNT(*) as nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E'
  AND total_nft_count > 0;

SELECT '=== 3. 日次利益データの存在確認 ===' as section;

-- 7E0A1Eの日次利益が記録されているか
SELECT
    date,
    daily_profit
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date DESC
LIMIT 5;

SELECT '=== 4. 紹介報酬の計算 ===' as section;

-- 手動で計算
SELECT
    SUM(udp.daily_profit) as level1_profit,
    SUM(udp.daily_profit) * 0.20 as referral_reward
FROM user_daily_profit udp
WHERE udp.user_id = '7E0A1E'
  AND udp.date >= DATE_TRUNC('month', CURRENT_DATE);

SELECT '=== 5. 関数内のクエリを再現 ===' as section;

-- 関数内と同じクエリ
SELECT
    u.referrer_user_id as user_id,
    COALESCE(SUM(udp.daily_profit) * 0.20, 0) as calculated_reward
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
WHERE u.referrer_user_id = '7A9637'
  AND u.has_approved_nft = true
  AND udp.date >= DATE_TRUNC('month', CURRENT_DATE)
  AND udp.date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE
GROUP BY u.referrer_user_id;

SELECT '=== 6. 問題の推測 ===' as section;

SELECT
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM users
            WHERE user_id = '7E0A1E'
              AND has_approved_nft = true
        )
        THEN '❌ 7E0A1Eのhas_approved_nftがfalse'

        WHEN NOT EXISTS (
            SELECT 1 FROM affiliate_cycle
            WHERE user_id = '7E0A1E'
              AND total_nft_count > 0
        )
        THEN '❌ 7E0A1EのNFTカウントが0'

        WHEN NOT EXISTS (
            SELECT 1 FROM user_daily_profit
            WHERE user_id = '7E0A1E'
        )
        THEN '❌ 7E0A1Eの日次利益データがない'

        ELSE '✅ データは揃っている。関数のロジックに問題がある可能性'
    END as diagnosis;

-- 完了メッセージ
DO $$
DECLARE
    v_has_approved BOOLEAN;
    v_nft_count INTEGER;
    v_profit_exists BOOLEAN;
BEGIN
    SELECT has_approved_nft INTO v_has_approved
    FROM users WHERE user_id = '7E0A1E';

    SELECT total_nft_count INTO v_nft_count
    FROM affiliate_cycle WHERE user_id = '7E0A1E';

    v_profit_exists := EXISTS(
        SELECT 1 FROM user_daily_profit WHERE user_id = '7E0A1E'
    );

    RAISE NOTICE '===========================================';
    RAISE NOTICE '紹介報酬が反映されない原因調査';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '7E0A1Eの状態:';
    RAISE NOTICE '  - has_approved_nft: %', v_has_approved;
    RAISE NOTICE '  - NFT count: %', v_nft_count;
    RAISE NOTICE '  - 日次利益データ: %', CASE WHEN v_profit_exists THEN 'あり' ELSE 'なし' END;
    RAISE NOTICE '';
    RAISE NOTICE 'もし全て正常なら、関数のSTEP 2に問題がある';
    RAISE NOTICE '===========================================';
END $$;
