-- ========================================
-- NFT買い取りとaffiliate_cycleの整合性チェック
-- ========================================
-- 目的: 他のユーザーで同様の問題が起こらないか調査
-- 問題: NFT買い取り時にaffiliate_cycleのNFTカウントが更新されていない可能性

-- 1. 全ユーザーのNFT実数とaffiliate_cycleの差異チェック
SELECT
    '1. NFT実数とaffiliate_cycleの差異' as section,
    nm.user_id,
    -- 実際のNFT数
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) as actual_manual_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL) as actual_auto_count,
    COUNT(*) FILTER (WHERE nm.buyback_date IS NULL) as actual_total_count,
    -- affiliate_cycleの記録
    ac.manual_nft_count as recorded_manual_count,
    ac.auto_nft_count as recorded_auto_count,
    ac.total_nft_count as recorded_total_count,
    -- 差異
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) - ac.manual_nft_count as manual_diff,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL) - ac.auto_nft_count as auto_diff,
    COUNT(*) FILTER (WHERE nm.buyback_date IS NULL) - ac.total_nft_count as total_diff,
    -- 買い取り済みNFT数
    COUNT(*) FILTER (WHERE nm.buyback_date IS NOT NULL) as buyback_count
FROM nft_master nm
INNER JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
GROUP BY nm.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count
HAVING
    -- 差異があるユーザーのみ表示
    COUNT(*) FILTER (WHERE nm.buyback_date IS NULL) != ac.total_nft_count
    OR COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) != ac.manual_nft_count
    OR COUNT(*) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL) != ac.auto_nft_count
ORDER BY total_diff DESC;

-- 2. 買い取り申請の処理状況を確認
SELECT
    '2. 買い取り申請の処理状況' as section,
    user_id,
    request_date,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    manual_buyback_amount,
    auto_buyback_amount,
    total_buyback_amount,
    processed_at,
    processed_by,
    status
FROM buyback_requests
WHERE status = 'completed'
ORDER BY processed_at DESC;

-- 3. 買い取り済みNFTの詳細（どのユーザーがいつ買い取ったか）
SELECT
    '3. 買い取り済みNFTの詳細' as section,
    user_id,
    nft_type,
    COUNT(*) as buyback_nft_count,
    MIN(buyback_date) as first_buyback_date,
    MAX(buyback_date) as last_buyback_date
FROM nft_master
WHERE buyback_date IS NOT NULL
GROUP BY user_id, nft_type
ORDER BY user_id, nft_type;

-- 4. affiliate_cycleのNFTカウントが0より大きいのに、実際のNFTが0のユーザー
SELECT
    '4. affiliate_cycleにNFTがあるが実際には0のユーザー' as section,
    ac.user_id,
    ac.total_nft_count as recorded_count,
    COALESCE(actual.active_count, 0) as actual_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase
FROM affiliate_cycle ac
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_count
    FROM nft_master
    GROUP BY user_id
) actual ON ac.user_id = actual.user_id
WHERE ac.total_nft_count > 0
  AND COALESCE(actual.active_count, 0) = 0;

-- 5. affiliate_cycleのNFTカウントが0なのに、実際にNFTがあるユーザー
SELECT
    '5. affiliate_cycleが0だが実際にはNFTがあるユーザー' as section,
    nm.user_id,
    COUNT(*) FILTER (WHERE nm.buyback_date IS NULL) as actual_count,
    ac.total_nft_count as recorded_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase
FROM nft_master nm
LEFT JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.buyback_date IS NULL
GROUP BY nm.user_id, ac.total_nft_count, ac.cum_usdt, ac.available_usdt, ac.phase
HAVING COALESCE(ac.total_nft_count, 0) = 0;

-- 6. 全体のサマリー
SELECT
    '6. 全体サマリー' as section,
    COUNT(DISTINCT user_id) as total_users_with_nft,
    SUM(CASE WHEN buyback_date IS NULL THEN 1 ELSE 0 END) as total_active_nft,
    SUM(CASE WHEN buyback_date IS NOT NULL THEN 1 ELSE 0 END) as total_buyback_nft,
    SUM(CASE WHEN buyback_date IS NULL AND nft_type = 'manual' THEN 1 ELSE 0 END) as active_manual,
    SUM(CASE WHEN buyback_date IS NULL AND nft_type = 'auto' THEN 1 ELSE 0 END) as active_auto
FROM nft_master;

-- 7. affiliate_cycleとの合計一致チェック
SELECT
    '7. affiliate_cycleの合計' as section,
    SUM(total_nft_count) as total_recorded_nft,
    SUM(manual_nft_count) as total_recorded_manual,
    SUM(auto_nft_count) as total_recorded_auto
FROM affiliate_cycle;

-- 完了メッセージ
SELECT '✅ 整合性チェック完了。差異があるユーザーは上記セクション1, 4, 5を確認してください。' as status;
