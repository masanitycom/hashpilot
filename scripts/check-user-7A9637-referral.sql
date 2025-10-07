-- ユーザー7A9637の紹介報酬とサイクル状況を確認
-- テストユーザー7E0A1Eの紹介報酬が正しく反映されているか

SELECT '=== 1. ユーザー7A9637の基本情報 ===' as section;

SELECT
    user_id,
    email,
    has_approved_nft,
    total_purchases,
    created_at
FROM users
WHERE user_id = '7A9637';

SELECT '=== 2. ユーザー7A9637のaffiliate_cycle状況 ===' as section;

SELECT
    user_id,
    phase,
    cycle_number,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    last_updated
FROM affiliate_cycle
WHERE user_id = '7A9637';

SELECT '=== 3. テストユーザー7E0A1Eの情報 ===' as section;

SELECT
    user_id,
    email,
    referrer_user_id,
    has_approved_nft,
    total_purchases,
    created_at
FROM users
WHERE user_id = '7E0A1E';

SELECT '=== 4. テストユーザー7E0A1Eのaffiliate_cycle ===' as section;

SELECT
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 5. 7E0A1Eの日次利益履歴（最新10件） ===' as section;

SELECT
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 6. 7A9637への紹介報酬計算（今月） ===' as section;

-- 今月の開始日と終了日
WITH date_range AS (
    SELECT
        DATE_TRUNC('month', CURRENT_DATE)::DATE as month_start,
        (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE as month_end
)
SELECT
    dr.month_start,
    dr.month_end,
    -- 7E0A1Eの今月の利益合計
    COALESCE(SUM(udp.daily_profit), 0) as level1_total_profit,
    -- 紹介報酬（20%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.20 as expected_referral_reward
FROM date_range dr
LEFT JOIN user_daily_profit udp ON
    udp.user_id = '7E0A1E'
    AND udp.date >= dr.month_start
    AND udp.date <= dr.month_end
GROUP BY dr.month_start, dr.month_end;

SELECT '=== 7. 7E0A1EのNFT状況 ===' as section;

SELECT
    COUNT(*) as total_nfts,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_nfts,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_nfts,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nfts
FROM nft_master
WHERE user_id = '7E0A1E';

SELECT
    id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date
FROM nft_master
WHERE user_id = '7E0A1E'
ORDER BY nft_sequence;

SELECT '=== 8. 紹介報酬が反映されているかチェック ===' as section;

-- NFTサイクルは紹介報酬のみで計算される
-- 7E0A1Eに66000ドルが入っているなら、60個のNFT (66000/1100)
-- その日利から20%が7A9637の紹介報酬として加算されるべき

SELECT
    '7E0A1Eの想定NFT数' as check_item,
    FLOOR(66000 / 1100) as expected_nft_count;

SELECT
    '7E0A1Eの実際のNFT数' as check_item,
    total_nft_count as actual_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 9. 日利計算が実行されているか ===' as section;

-- 最新の日利計算日を確認
SELECT
    date,
    COUNT(*) as users_processed,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date DESC
LIMIT 7;

SELECT '=== 10. まとめ ===' as section;

SELECT
    '7A9637のcum_usdt' as item,
    cum_usdt as value,
    CASE
        WHEN cum_usdt >= 2200 THEN '✅ NFT自動付与条件を満たしている'
        WHEN cum_usdt >= 1100 THEN '⚠️ HOLDフェーズ（次のサイクルまで待機）'
        ELSE '📊 USDTフェーズ（紹介報酬蓄積中）'
    END as status
FROM affiliate_cycle
WHERE user_id = '7A9637';
