-- ========================================
-- 11/30の日利処理が正しく実行されたか確認
-- ========================================

-- 1. system_logs で11/30の処理ログを確認
SELECT '=== 1. 11/30の処理ログ ===' as section;

SELECT
    log_type,
    message,
    details,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM system_logs
WHERE created_at >= '2025-11-30'
  AND created_at < '2025-12-02'
ORDER BY created_at DESC;

-- 2. nft_daily_profit の11/30データの作成日時
SELECT '=== 2. nft_daily_profit の11/30データ作成日時 ===' as section;

SELECT
    date,
    COUNT(*) as record_count,
    MIN(created_at) AT TIME ZONE 'Asia/Tokyo' as first_created_jst,
    MAX(created_at) AT TIME ZONE 'Asia/Tokyo' as last_created_jst
FROM nft_daily_profit
WHERE date = '2025-11-30'
GROUP BY date;

-- 3. user_daily_profit の11/30データの作成日時
SELECT '=== 3. user_daily_profit の11/30データ作成日時 ===' as section;

SELECT
    date,
    COUNT(*) as record_count,
    MIN(created_at) AT TIME ZONE 'Asia/Tokyo' as first_created_jst,
    MAX(created_at) AT TIME ZONE 'Asia/Tokyo' as last_created_jst
FROM user_daily_profit
WHERE date = '2025-11-30'
GROUP BY date;

-- 4. user_referral_profit の11/30データの作成日時
SELECT '=== 4. user_referral_profit の11/30データ作成日時 ===' as section;

SELECT
    date,
    COUNT(*) as record_count,
    MIN(created_at) AT TIME ZONE 'Asia/Tokyo' as first_created_jst,
    MAX(created_at) AT TIME ZONE 'Asia/Tokyo' as last_created_jst
FROM user_referral_profit
WHERE date = '2025-11-30'
GROUP BY date;

-- 5. affiliate_cycle の最終更新日時（上位20名）
SELECT '=== 5. affiliate_cycle の最終更新日時（上位20名） ===' as section;

SELECT
    ac.user_id,
    u.email,
    ac.available_usdt,
    ac.cum_usdt,
    ac.updated_at AT TIME ZONE 'Asia/Tokyo' as updated_at_jst
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true
ORDER BY ac.updated_at DESC
LIMIT 20;

-- 6. 11/30以降に更新されたaffiliate_cycleレコード数
SELECT '=== 6. 11/30以降に更新されたaffiliate_cycleレコード ===' as section;

SELECT
    COUNT(*) as updated_count,
    MIN(updated_at) AT TIME ZONE 'Asia/Tokyo' as first_update_jst,
    MAX(updated_at) AT TIME ZONE 'Asia/Tokyo' as last_update_jst
FROM affiliate_cycle
WHERE updated_at >= '2025-11-30';

-- 7. 特定ユーザーの11/30の日利・紹介報酬の詳細（サンプル5名）
SELECT '=== 7. サンプルユーザーの11/30詳細（5名） ===' as section;

WITH sample_users AS (
    SELECT user_id
    FROM users
    WHERE has_approved_nft = true
    ORDER BY user_id
    LIMIT 5
)
SELECT
    su.user_id,
    COALESCE(udp.daily_profit, 0) as daily_profit_1130,
    COALESCE(urp_sum.referral_profit, 0) as referral_profit_1130,
    ac.available_usdt as current_available,
    ac.updated_at AT TIME ZONE 'Asia/Tokyo' as ac_updated_at_jst
FROM sample_users su
LEFT JOIN user_daily_profit udp ON su.user_id = udp.user_id AND udp.date = '2025-11-30'
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as referral_profit
    FROM user_referral_profit
    WHERE date = '2025-11-30'
    GROUP BY user_id
) urp_sum ON su.user_id = urp_sum.user_id
INNER JOIN affiliate_cycle ac ON su.user_id = ac.user_id
ORDER BY su.user_id;

-- 8. process_daily_yield_v2 の実行履歴確認
SELECT '=== 8. daily_yield_processing の実行履歴 ===' as section;

SELECT
    processing_date,
    total_pnl,
    processed_users,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM daily_yield_processing
WHERE processing_date >= '2025-11-01'
ORDER BY processing_date DESC;

-- 9. 11/30に作成されたすべてのレコードのサマリー
DO $$
DECLARE
    v_nft_daily_profit_count INTEGER;
    v_user_daily_profit_count INTEGER;
    v_user_referral_profit_count INTEGER;
    v_affiliate_cycle_updated INTEGER;
    v_nft_daily_total NUMERIC;
    v_user_daily_total NUMERIC;
    v_user_referral_total NUMERIC;
BEGIN
    -- nft_daily_profit
    SELECT COUNT(*), COALESCE(SUM(daily_profit), 0)
    INTO v_nft_daily_profit_count, v_nft_daily_total
    FROM nft_daily_profit
    WHERE date = '2025-11-30';

    -- user_daily_profit
    SELECT COUNT(*), COALESCE(SUM(daily_profit), 0)
    INTO v_user_daily_profit_count, v_user_daily_total
    FROM user_daily_profit
    WHERE date = '2025-11-30';

    -- user_referral_profit
    SELECT COUNT(*), COALESCE(SUM(profit_amount), 0)
    INTO v_user_referral_profit_count, v_user_referral_total
    FROM user_referral_profit
    WHERE date = '2025-11-30';

    -- affiliate_cycle updated
    SELECT COUNT(*)
    INTO v_affiliate_cycle_updated
    FROM affiliate_cycle
    WHERE updated_at >= '2025-11-30 00:00:00'
      AND updated_at < '2025-12-01 00:00:00';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 11/30の処理状況サマリー';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'nft_daily_profit:';
    RAISE NOTICE '  レコード数: %', v_nft_daily_profit_count;
    RAISE NOTICE '  総額: $%', v_nft_daily_total;
    RAISE NOTICE '';
    RAISE NOTICE 'user_daily_profit:';
    RAISE NOTICE '  レコード数: %', v_user_daily_profit_count;
    RAISE NOTICE '  総額: $%', v_user_daily_total;
    RAISE NOTICE '';
    RAISE NOTICE 'user_referral_profit:';
    RAISE NOTICE '  レコード数: %', v_user_referral_profit_count;
    RAISE NOTICE '  総額: $%', v_user_referral_total;
    RAISE NOTICE '';
    RAISE NOTICE '配布合計: $%', v_user_daily_total + v_user_referral_total;
    RAISE NOTICE '';
    RAISE NOTICE 'affiliate_cycle:';
    RAISE NOTICE '  11/30に更新されたレコード数: %', v_affiliate_cycle_updated;
    RAISE NOTICE '';
    RAISE NOTICE '🚨 問題:';
    IF v_affiliate_cycle_updated = 0 THEN
        RAISE NOTICE '  affiliate_cycleが11/30に更新されていない！';
    ELSIF v_affiliate_cycle_updated < v_user_daily_profit_count THEN
        RAISE NOTICE '  affiliate_cycleの更新数（%）が配布ユーザー数（%）より少ない！',
            v_affiliate_cycle_updated, v_user_daily_profit_count;
    ELSE
        RAISE NOTICE '  affiliate_cycleは正常に更新されている';
    END IF;
    RAISE NOTICE '===========================================';
END $$;
