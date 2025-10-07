-- 7E0A1Eの詳細調査：なぜ紹介報酬が発生していないか

SELECT '=== 1. 7E0A1Eのユーザー情報 ===' as section;

SELECT
    user_id,
    email,
    has_approved_nft,
    total_purchases,
    referrer_user_id,
    created_at
FROM users
WHERE user_id = '7E0A1E';

SELECT '=== 2. 7E0A1EのNFT購入記録 ===' as section;

SELECT
    id,
    user_id,
    nft_quantity,
    amount_usd,
    admin_approved,
    admin_approved_at,
    is_auto_purchase,
    created_at
FROM purchases
WHERE user_id = '7E0A1E'
ORDER BY created_at DESC;

SELECT '=== 3. 7E0A1EのNFTマスター（実際のNFT） ===' as section;

SELECT
    id,
    user_id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
ORDER BY nft_sequence;

SELECT '=== 4. 7E0A1Eのaffiliate_cycle ===' as section;

SELECT
    user_id,
    phase,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    created_at,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 5. 7E0A1Eの日次利益（最新10件） ===' as section;

SELECT
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 6. 問題診断 ===' as section;

SELECT
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM users WHERE user_id = '7E0A1E')
        THEN '❌ ユーザーが存在しません'

        WHEN (SELECT has_approved_nft FROM users WHERE user_id = '7E0A1E') = FALSE
        THEN '⚠️ NFTが未承認です（has_approved_nft = false）'

        WHEN NOT EXISTS (SELECT 1 FROM purchases WHERE user_id = '7E0A1E' AND admin_approved = true)
        THEN '⚠️ 承認済みの購入記録がありません'

        WHEN NOT EXISTS (SELECT 1 FROM nft_master WHERE user_id = '7E0A1E' AND buyback_date IS NULL)
        THEN '⚠️ 有効なNFTレコードがありません'

        WHEN (SELECT total_nft_count FROM affiliate_cycle WHERE user_id = '7E0A1E') = 0
        THEN '⚠️ affiliate_cycleのNFTカウントが0です'

        WHEN NOT EXISTS (SELECT 1 FROM user_daily_profit WHERE user_id = '7E0A1E')
        THEN '⚠️ 日利計算が実行されていません'

        ELSE '✅ データは正常に見えます'
    END as diagnosis;

SELECT '=== 7. 修正が必要な場合のSQL ===' as section;

-- もし has_approved_nft = false なら、これを実行
SELECT
    'UPDATE users SET has_approved_nft = true WHERE user_id = ''7E0A1E'';' as fix_sql_1
WHERE EXISTS (SELECT 1 FROM users WHERE user_id = '7E0A1E' AND has_approved_nft = false);

-- もし affiliate_cycle にレコードがないなら
SELECT
    'INSERT INTO affiliate_cycle (user_id, phase, total_nft_count) VALUES (''7E0A1E'', ''USDT'', 60);' as fix_sql_2
WHERE NOT EXISTS (SELECT 1 FROM affiliate_cycle WHERE user_id = '7E0A1E');

-- もし nft_master にレコードがないなら（60個のNFTを作成する必要がある）
SELECT
    'ユーザー7E0A1Eに60個のNFTレコードを作成する必要があります' as fix_sql_3
WHERE NOT EXISTS (SELECT 1 FROM nft_master WHERE user_id = '7E0A1E');
