-- 承認結果の確認

-- E28F37ユーザーのNFTマスターとaffiliate_cycleの整合性確認
SELECT
    '=== 承認後の確認（E28F37） ===' as section,
    COALESCE(nm.user_id, ac.user_id) as user_id,
    COALESCE(nm.manual_count, 0) as nft_master_manual_count,
    COALESCE(ac.manual_nft_count, 0) as affiliate_cycle_manual_count,
    COALESCE(nm.total_count, 0) as nft_master_total_count,
    COALESCE(ac.total_nft_count, 0) as affiliate_cycle_total_count,
    CASE
        WHEN COALESCE(nm.total_count, 0) = COALESCE(ac.total_nft_count, 0)
        THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as status
FROM (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_count,
        COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_count
    FROM nft_master
    WHERE user_id = 'E28F37'
    GROUP BY user_id
) nm
FULL OUTER JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE COALESCE(nm.user_id, ac.user_id) = 'E28F37';

-- NFTマスターの詳細確認
SELECT
    '=== NFTマスター詳細 ===' as section,
    id,
    user_id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date
FROM nft_master
WHERE user_id = 'E28F37'
ORDER BY nft_sequence;

-- purchasesテーブルの確認
SELECT
    '=== 購入レコード ===' as section,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    admin_approved,
    admin_approved_at,
    admin_approved_by
FROM purchases
WHERE id = 'ecee97ac-0519-4a41-b53e-03e05d033d9c';
