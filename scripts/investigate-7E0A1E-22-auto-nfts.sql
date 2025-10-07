-- 7E0A1Eに22個の自動NFTが付与された原因を調査

SELECT '=== 1. 7E0A1Eの現在の状態 ===' as section;

SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    cycle_number,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 2. 7E0A1Eの実際のNFTレコード ===' as section;

-- 手動NFTと自動NFTを分けて確認
SELECT
    nft_type,
    COUNT(*) as nft_count,
    MIN(acquired_date) as first_acquired,
    MAX(acquired_date) as last_acquired
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL
GROUP BY nft_type;

-- 自動NFTの詳細
SELECT
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
  AND nft_type = 'auto'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

SELECT '=== 3. 自動購入履歴 ===' as section;

SELECT
    id,
    nft_quantity,
    amount_usd,
    admin_approved_at,
    created_at,
    is_auto_purchase
FROM purchases
WHERE user_id = '7E0A1E'
  AND is_auto_purchase = true
ORDER BY created_at;

SELECT '=== 4. 7E0A1Eは紹介者なし ===' as section;

-- 紹介者がいるか確認
SELECT
    COUNT(*) as referral_count
FROM users
WHERE referrer_user_id = '7E0A1E';

-- 7E0A1Eの紹介報酬（0のはず）
SELECT
    COALESCE(SUM(udp.daily_profit) * 0.20, 0) as should_be_zero
FROM user_daily_profit udp
WHERE udp.user_id IN (
    SELECT user_id FROM users
    WHERE referrer_user_id = '7E0A1E'
      AND has_approved_nft = true
)
AND udp.date >= DATE_TRUNC('month', CURRENT_DATE);

SELECT '=== 5. cum_usdtの履歴を推測 ===' as section;

-- 22個のNFT付与 = 22 × 2200 = 48,400ドルのcum_usdt

SELECT
    '必要なcum_usdt' as item,
    22 * 2200 as value,
    '22個のNFTを付与するには48,400ドル必要' as note;

SELECT
    '7E0A1Eの現在のcum_usdt' as item,
    cum_usdt as value,
    'NFT付与後の残額' as note
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 6. 個人利益がcum_usdtに加算された？ ===' as section;

-- 7E0A1Eの今月の個人利益
SELECT
    SUM(daily_profit) as total_personal_profit,
    '7E0A1Eの今月の個人利益' as description
FROM user_daily_profit
WHERE user_id = '7E0A1E'
  AND date >= DATE_TRUNC('month', CURRENT_DATE);

-- もし個人利益がcum_usdtに加算されていたら
SELECT
    FLOOR(SUM(daily_profit) / 2200) as would_grant_nfts,
    '個人利益がcum_usdtに入った場合のNFT数' as description
FROM user_daily_profit
WHERE user_id = '7E0A1E'
  AND date >= DATE_TRUNC('month', CURRENT_DATE);

SELECT '=== 7. バグの原因推測 ===' as section;

SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM users WHERE referrer_user_id = '7E0A1E') = 0
             AND (SELECT auto_nft_count FROM affiliate_cycle WHERE user_id = '7E0A1E') > 0
        THEN '⚠️ バグ: 紹介者0人なのに自動NFT付与されている'
        ELSE '正常'
    END as bug_status;

SELECT
    '推測される原因' as analysis,
    '個人利益がcum_usdtに誤って加算され、NFT自動付与が発動した' as likely_cause;

SELECT '=== 8. 正しい動作 ===' as section;

SELECT
    '紹介者なし' as condition,
    '紹介報酬 = 0' as referral_reward,
    'cum_usdt = 0（紹介報酬のみ）' as cum_usdt_should_be,
    '自動NFT付与なし' as expected_behavior;

SELECT '=== 9. 実際に起きたこと ===' as section;

SELECT
    '紹介者なし' as condition,
    '個人利益が大きい（$43,581）' as personal_profit,
    'cum_usdtに個人利益が入った？' as what_happened,
    '22個の自動NFT付与' as result;

-- 完了メッセージ
DO $$
DECLARE
    v_auto_nft_count INTEGER;
    v_cum_usdt NUMERIC;
    v_personal_profit NUMERIC;
BEGIN
    SELECT auto_nft_count, cum_usdt
    INTO v_auto_nft_count, v_cum_usdt
    FROM affiliate_cycle
    WHERE user_id = '7E0A1E';

    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_personal_profit
    FROM user_daily_profit
    WHERE user_id = '7E0A1E'
      AND date >= DATE_TRUNC('month', CURRENT_DATE);

    RAISE NOTICE '===========================================';
    RAISE NOTICE '7E0A1Eの自動NFT付与バグ調査';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '自動NFT数: %個', v_auto_nft_count;
    RAISE NOTICE '現在のcum_usdt: $%', v_cum_usdt;
    RAISE NOTICE '今月の個人利益: $%', v_personal_profit;
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ 問題:';
    RAISE NOTICE '  - 紹介者0人なのに自動NFT付与';
    RAISE NOTICE '  - 個人利益がcum_usdtに混入した可能性';
    RAISE NOTICE '';
    RAISE NOTICE '💡 原因:';
    RAISE NOTICE '  - NFTサイクルは紹介報酬のみで計算すべき';
    RAISE NOTICE '  - 個人利益はavailable_usdtに直接加算';
    RAISE NOTICE '===========================================';
END $$;
