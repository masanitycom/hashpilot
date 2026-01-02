-- ========================================
-- ユーザー 59C23C のNFT自動付与を手動実行
-- ========================================
-- cum_usdt = $2,477.37 で $2,200 を超えているため
-- 1 NFT を自動付与し、cum_usdt から $1,100 を差し引く
-- ========================================

-- 現状確認
SELECT '=== 修正前の状態 ===' as section;
SELECT
    user_id,
    cum_usdt,
    available_usdt,
    phase,
    auto_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- ========================================
-- STEP 1: nft_master にNFTを追加
-- ========================================
INSERT INTO nft_master (
    user_id,
    nft_type,
    acquired_date,
    created_at
) VALUES (
    '59C23C',
    'auto',
    CURRENT_DATE,
    NOW()
);

-- ========================================
-- STEP 2: purchases にレコード追加
-- ========================================
INSERT INTO purchases (
    user_id,
    amount_usd,
    admin_approved,
    is_auto_purchase,
    cycle_number_at_purchase,
    created_at
) VALUES (
    '59C23C',
    1100.00,
    true,
    true,
    1,  -- 1回目のサイクル
    NOW()
);

-- ========================================
-- STEP 3: affiliate_cycle を更新
-- ========================================
UPDATE affiliate_cycle
SET
    cum_usdt = cum_usdt - 1100,  -- $2,477.37 - $1,100 = $1,377.37
    available_usdt = available_usdt + 1100,  -- $1,124.58 + $1,100 = $2,224.58
    auto_nft_count = auto_nft_count + 1,  -- 0 + 1 = 1
    phase = CASE
        WHEN (FLOOR((cum_usdt - 1100) / 1100)::int % 2) = 0 THEN 'USDT'
        ELSE 'HOLD'
    END,
    updated_at = NOW()
WHERE user_id = '59C23C';

-- ========================================
-- STEP 4: 結果確認
-- ========================================
SELECT '=== 修正後の状態 ===' as section;
SELECT
    user_id,
    cum_usdt,
    available_usdt,
    phase,
    auto_nft_count,
    manual_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';

SELECT '=== NFT一覧 ===' as section;
SELECT
    id,
    nft_type,
    acquired_date,
    created_at
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY created_at;

SELECT '=== 購入履歴 ===' as section;
SELECT
    id,
    amount_usd,
    is_auto_purchase,
    cycle_number_at_purchase,
    created_at
FROM purchases
WHERE user_id = '59C23C'
ORDER BY created_at;
