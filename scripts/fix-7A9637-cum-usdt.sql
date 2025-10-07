-- 7A9637のcum_usdtを実際の紹介報酬で更新
-- 現在: 120.98ドル
-- 実際: 8759.30ドル（今月の紹介報酬）

SELECT '=== 修正前の状態 ===' as section;

SELECT
    user_id,
    cum_usdt as current_cum_usdt,
    phase,
    total_nft_count,
    auto_nft_count
FROM affiliate_cycle
WHERE user_id = '7A9637';

SELECT '=== 実際の紹介報酬 ===' as section;

SELECT
    SUM(udp.daily_profit) * 0.20 as actual_referral_reward
FROM user_daily_profit udp
WHERE udp.user_id IN (
    SELECT user_id FROM users
    WHERE referrer_user_id = '7A9637'
      AND has_approved_nft = true
)
AND udp.date >= DATE_TRUNC('month', CURRENT_DATE);

SELECT '=== 修正実行 ===' as section;

-- cum_usdtを実際の紹介報酬で更新
UPDATE affiliate_cycle
SET
    cum_usdt = (
        SELECT COALESCE(SUM(udp.daily_profit) * 0.20, 0)
        FROM user_daily_profit udp
        WHERE udp.user_id IN (
            SELECT user_id FROM users
            WHERE referrer_user_id = '7A9637'
              AND has_approved_nft = true
        )
        AND udp.date >= DATE_TRUNC('month', CURRENT_DATE)
    ),
    -- フェーズも更新
    phase = CASE
        WHEN (
            SELECT COALESCE(SUM(udp.daily_profit) * 0.20, 0)
            FROM user_daily_profit udp
            WHERE udp.user_id IN (
                SELECT user_id FROM users
                WHERE referrer_user_id = '7A9637'
                  AND has_approved_nft = true
            )
            AND udp.date >= DATE_TRUNC('month', CURRENT_DATE)
        ) >= 2200 THEN 'HOLD'
        WHEN (
            SELECT COALESCE(SUM(udp.daily_profit) * 0.20, 0)
            FROM user_daily_profit udp
            WHERE udp.user_id IN (
                SELECT user_id FROM users
                WHERE referrer_user_id = '7A9637'
                  AND has_approved_nft = true
            )
            AND udp.date >= DATE_TRUNC('month', CURRENT_DATE)
        ) >= 1100 THEN 'HOLD'
        ELSE 'USDT'
    END,
    last_updated = NOW()
WHERE user_id = '7A9637';

SELECT '=== 修正後の状態 ===' as section;

SELECT
    user_id,
    cum_usdt as updated_cum_usdt,
    phase,
    total_nft_count,
    auto_nft_count
FROM affiliate_cycle
WHERE user_id = '7A9637';

SELECT '=== 自動NFT付与の判定 ===' as section;

SELECT
    CASE
        WHEN cum_usdt >= 2200
        THEN FORMAT('✅ 自動NFT付与条件を満たしています！ %s個のNFTを付与すべきです', FLOOR(cum_usdt / 2200))
        WHEN cum_usdt >= 1100
        THEN '⚠️ HOLDフェーズ: 次のサイクルまであと$' || (2200 - cum_usdt)::TEXT
        ELSE '📊 USDTフェーズ: 蓄積中'
    END as nft_grant_status
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 完了メッセージ
DO $$
DECLARE
    v_cum_usdt NUMERIC;
    v_nft_count INTEGER;
BEGIN
    SELECT cum_usdt INTO v_cum_usdt
    FROM affiliate_cycle
    WHERE user_id = '7A9637';

    v_nft_count := FLOOR(v_cum_usdt / 2200);

    RAISE NOTICE '===========================================';
    RAISE NOTICE '7A9637のcum_usdt更新完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '更新後のcum_usdt: $%', v_cum_usdt;

    IF v_cum_usdt >= 2200 THEN
        RAISE NOTICE '✅ 自動NFT付与: %個のNFTを付与できます', v_nft_count;
        RAISE NOTICE '';
        RAISE NOTICE '次のステップ:';
        RAISE NOTICE '  日利計算を実行してNFTを自動付与してください';
    END IF;

    RAISE NOTICE '===========================================';
END $$;
