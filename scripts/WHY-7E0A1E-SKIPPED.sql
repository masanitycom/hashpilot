-- なぜ7E0A1Eが日利計算でスキップされたか調査

-- 1. 7E0A1Eの基本情報
SELECT
    '1. ユーザー情報' as section,
    user_id,
    has_approved_nft,
    operation_start_date,
    created_at
FROM users
WHERE user_id = '7E0A1E';

-- 2. NFT数（buyback除く）
SELECT
    '2. アクティブNFT' as section,
    COUNT(*) as active_nft_count,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_count,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_count
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL;

-- 3. affiliate_cycle
SELECT
    '3. affiliate_cycle' as section,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 4. 日利計算の条件チェック
SELECT
    '4. 日利計算条件チェック' as section,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ operation_start_dateがNULL'
        WHEN u.operation_start_date > '2025-10-01' THEN FORMAT('❌ operation_start_dateが未来: %s', u.operation_start_date)
        WHEN NOT u.has_approved_nft THEN '❌ has_approved_nftがfalse'
        WHEN ac.total_nft_count = 0 THEN '❌ total_nft_countが0'
        ELSE '✅ 全ての条件を満たしている'
    END as status,
    u.operation_start_date,
    u.has_approved_nft,
    ac.total_nft_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = '7E0A1E';

-- 5. STEP1のクエリを実際に実行してみる（10/1の場合）
SELECT
    '5. STEP1クエリテスト（10/1）' as section,
    nm.id as nft_id,
    nm.user_id,
    nm.nft_type,
    nm.nft_value,
    u.operation_start_date
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
WHERE nm.user_id = '7E0A1E'
  AND nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-10-01';

-- 6. 他のユーザーはデータがあるか
SELECT
    '6. 他のユーザーの日利データ' as section,
    user_id,
    COUNT(*) as profit_records
FROM nft_daily_profit
WHERE date >= '2025-10-01'
GROUP BY user_id
ORDER BY profit_records DESC
LIMIT 5;
