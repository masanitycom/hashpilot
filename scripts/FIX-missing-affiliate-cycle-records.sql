-- ========================================
-- affiliate_cycleに登録されていないユーザーを修正
-- ========================================
-- 目的: NFTを持っているのにaffiliate_cycleレコードがないユーザーを修正
-- 対象: 2F0B1F, 368E3F, E7F984, F38DF5

-- 1. 現在の状態を確認
SELECT
    '修正前: 対象ユーザーのNFT' as section,
    nm.user_id,
    COUNT(*) as nft_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual') as manual_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto') as auto_count,
    ac.user_id as affiliate_cycle_exists
FROM nft_master nm
LEFT JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.user_id IN ('2F0B1F', '368E3F', 'E7F984', 'F38DF5')
  AND nm.buyback_date IS NULL
GROUP BY nm.user_id, ac.user_id
ORDER BY nm.user_id;

-- 2. 不足しているaffiliate_cycleレコードを作成
INSERT INTO affiliate_cycle (
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    cycle_number,
    last_updated
)
SELECT
    nm.user_id,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual') as manual_nft_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto') as auto_nft_count,
    COUNT(*) as total_nft_count,
    0.00 as cum_usdt,
    0.00 as available_usdt,
    'USDT' as phase,
    0 as cycle_number,
    NOW() as last_updated
FROM nft_master nm
WHERE nm.user_id IN ('2F0B1F', '368E3F', 'E7F984', 'F38DF5')
  AND nm.buyback_date IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM affiliate_cycle ac WHERE ac.user_id = nm.user_id
  )
GROUP BY nm.user_id;

-- 3. 修正後の状態を確認
SELECT
    '修正後: 対象ユーザーのaffiliate_cycle' as section,
    ac.user_id,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase
FROM affiliate_cycle ac
WHERE ac.user_id IN ('2F0B1F', '368E3F', 'E7F984', 'F38DF5')
ORDER BY ac.user_id;

-- 4. 全体の整合性を再チェック
SELECT
    '修正後: 全体サマリー' as section,
    (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) as actual_active_nft,
    (SELECT SUM(total_nft_count) FROM affiliate_cycle) as recorded_total_nft,
    (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) -
    (SELECT SUM(total_nft_count) FROM affiliate_cycle) as difference
;

-- 完了メッセージ
SELECT '✅ 4人のユーザーのaffiliate_cycleレコードを作成しました' as status;
