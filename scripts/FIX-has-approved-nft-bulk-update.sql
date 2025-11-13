-- ========================================
-- NFT承認フラグとoperration_start_dateの一括更新
-- ========================================
--
-- 問題:
-- NFT承認済みなのに has_approved_nft = false のままで
-- operation_start_date = NULL のユーザーが存在
-- → 日利と紹介報酬の対象外になっていた
--
-- 対象:
-- - has_approved_nft 更新: 361レコード
-- - operation_start_date 更新: 363レコード
--
-- 実行日: 2025-11-13
-- ========================================

-- ========================================
-- Step 1: has_approved_nft を true に更新
-- ========================================
-- 条件:
-- - nft_master に NFT が存在
-- - purchases で admin_approved = true
-- - NFT は買い取り済みでない (buyback_date IS NULL)
-- - has_approved_nft が false のまま
UPDATE users
SET has_approved_nft = true
WHERE user_id IN (
    SELECT DISTINCT u.user_id
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    INNER JOIN purchases p ON u.user_id = p.user_id
    WHERE u.has_approved_nft = false
        AND p.admin_approved = true
        AND nm.buyback_date IS NULL
);

-- ========================================
-- Step 2: operation_start_date を設定
-- ========================================
-- 条件:
-- - nft_master に NFT が存在（買い取り済みでないもの）
-- - operation_start_date が NULL
-- - 最初の NFT の acquired_date から calculate_operation_start_date() で計算
UPDATE users u
SET operation_start_date = calculate_operation_start_date(nm.acquired_date)
FROM (
    SELECT DISTINCT ON (user_id)
        user_id,
        acquired_date
    FROM nft_master
    WHERE buyback_date IS NULL
    ORDER BY user_id, acquired_date ASC
) nm
WHERE u.user_id = nm.user_id
    AND u.operation_start_date IS NULL;

-- ========================================
-- 検証クエリ（実行後確認用）
-- ========================================

-- has_approved_nft が false だが NFT が存在するユーザー（0件が正常）
SELECT
    u.user_id,
    u.full_name,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(DISTINCT nm.id) as nft_count,
    COUNT(DISTINCT p.id) as purchase_count
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.has_approved_nft = false
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.full_name, u.has_approved_nft, u.operation_start_date;

-- operation_start_date が NULL だが NFT が存在するユーザー（0件が正常）
SELECT
    u.user_id,
    u.full_name,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(nm.id) as nft_count,
    MIN(nm.acquired_date) as first_acquired_date
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date IS NULL
    AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.full_name, u.has_approved_nft, u.operation_start_date;
