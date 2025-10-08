-- 全システムの整合性チェック
-- 買い取り、自動NFT付与、日利計算への影響確認

-- ============================================
-- 1. 全ユーザーのNFTデータ整合性チェック
-- ============================================

SELECT '=== 1. NFTデータ整合性チェック ===' as section;

SELECT
    COALESCE(nm.user_id, ac.user_id) as user_id,
    COALESCE(nm.manual_count, 0) as nft_master_manual,
    COALESCE(nm.auto_count, 0) as nft_master_auto,
    COALESCE(nm.total_count, 0) as nft_master_total,
    COALESCE(ac.manual_nft_count, 0) as affiliate_cycle_manual,
    COALESCE(ac.auto_nft_count, 0) as affiliate_cycle_auto,
    COALESCE(ac.total_nft_count, 0) as affiliate_cycle_total,
    CASE
        WHEN COALESCE(nm.manual_count, 0) = COALESCE(ac.manual_nft_count, 0)
            AND COALESCE(nm.auto_count, 0) = COALESCE(ac.auto_nft_count, 0)
            AND COALESCE(nm.total_count, 0) = COALESCE(ac.total_nft_count, 0)
        THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as status
FROM (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_count,
        COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as auto_count,
        COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_count
    FROM nft_master
    GROUP BY user_id
) nm
FULL OUTER JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE COALESCE(ac.total_nft_count, 0) > 0 OR COALESCE(nm.total_count, 0) > 0
ORDER BY
    CASE
        WHEN COALESCE(nm.manual_count, 0) = COALESCE(ac.manual_nft_count, 0)
            AND COALESCE(nm.auto_count, 0) = COALESCE(ac.auto_nft_count, 0)
            AND COALESCE(nm.total_count, 0) = COALESCE(ac.total_nft_count, 0)
        THEN 1
        ELSE 0
    END,
    COALESCE(nm.user_id, ac.user_id);

-- ============================================
-- 2. 買い取り機能への影響チェック
-- ============================================

SELECT '=== 2. 買い取り機能チェック ===' as section;

-- create_buyback_request関数がnft_masterから正しくNFT数を取得できるか確認
SELECT
    user_id,
    COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as available_manual_nfts,
    COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as available_auto_nfts,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_available_nfts
FROM nft_master
GROUP BY user_id
HAVING COUNT(*) FILTER (WHERE buyback_date IS NULL) > 0
ORDER BY user_id
LIMIT 10;

-- 買い取り申請中のユーザーがいるか確認
SELECT
    '買い取り申請状況' as check_point,
    COUNT(*) as pending_buyback_requests
FROM buyback_requests
WHERE status = 'pending';

-- ============================================
-- 3. 自動NFT付与機能への影響チェック
-- ============================================

SELECT '=== 3. 自動NFT付与機能チェック ===' as section;

-- cum_usdtが2200に近いユーザー（次回の日利計算で自動NFT付与される可能性）
SELECT
    user_id,
    cum_usdt,
    total_nft_count,
    auto_nft_count,
    phase,
    FLOOR(cum_usdt / 2200) as potential_auto_nft_grants
FROM affiliate_cycle
WHERE cum_usdt >= 1100
ORDER BY cum_usdt DESC
LIMIT 10;

-- 最近自動NFT付与されたユーザーの確認
SELECT
    user_id,
    nft_sequence,
    nft_type,
    acquired_date
FROM nft_master
WHERE nft_type = 'auto'
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 4. 日利計算機能への影響チェック
-- ============================================

SELECT '=== 4. 日利計算機能チェック ===' as section;

-- process_daily_yield_with_cycles関数がnft_masterから正しくNFTを取得できるか
SELECT
    nm.user_id,
    COUNT(*) as nft_count_for_daily_profit,
    ac.total_nft_count as expected_nft_count,
    CASE
        WHEN COUNT(*) = ac.total_nft_count THEN '✅ 正常'
        ELSE '⚠️ 不一致'
    END as status
FROM nft_master nm
INNER JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.buyback_date IS NULL
GROUP BY nm.user_id, ac.total_nft_count
ORDER BY nm.user_id
LIMIT 10;

-- 最新の日利計算ログ確認
SELECT
    date,
    yield_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;

-- ============================================
-- 5. NFTシーケンス番号の重複チェック
-- ============================================

SELECT '=== 5. NFTシーケンス重複チェック ===' as section;

SELECT
    user_id,
    nft_sequence,
    COUNT(*) as duplicate_count
FROM nft_master
GROUP BY user_id, nft_sequence
HAVING COUNT(*) > 1
ORDER BY user_id, nft_sequence;

-- ============================================
-- 6. 関数の存在確認
-- ============================================

SELECT '=== 6. 重要な関数の存在確認 ===' as section;

SELECT
    proname as function_name,
    CASE
        WHEN proname = 'approve_user_nft' THEN '✅ 購入承認'
        WHEN proname = 'create_buyback_request' THEN '✅ 買い取り申請'
        WHEN proname = 'get_buyback_requests' THEN '✅ 買い取り履歴取得'
        WHEN proname = 'process_daily_yield_with_cycles' THEN '✅ 日利計算'
        WHEN proname = 'calculate_nft_buyback_amount' THEN '✅ NFT買い取り金額計算'
        ELSE proname
    END as description
FROM pg_proc
WHERE proname IN (
    'approve_user_nft',
    'create_buyback_request',
    'get_buyback_requests',
    'process_daily_yield_with_cycles',
    'calculate_nft_buyback_amount'
)
ORDER BY proname;

-- ============================================
-- 完了メッセージ
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ システム整合性チェック完了';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '';
    RAISE NOTICE '確認項目:';
    RAISE NOTICE '  1. NFTデータ整合性（nft_master vs affiliate_cycle）';
    RAISE NOTICE '  2. 買い取り機能（available NFTs）';
    RAISE NOTICE '  3. 自動NFT付与機能（cum_usdt >= 2200）';
    RAISE NOTICE '  4. 日利計算機能（NFT count）';
    RAISE NOTICE '  5. NFTシーケンス重複';
    RAISE NOTICE '  6. 重要な関数の存在';
    RAISE NOTICE '';
    RAISE NOTICE '不一致があった場合:';
    RAISE NOTICE '  - sync-nft-master-from-affiliate-cycle.sql を実行';
    RAISE NOTICE '=========================================';
END $$;
