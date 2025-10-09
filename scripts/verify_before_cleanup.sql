-- クリーンアップ前の検証
-- manual_nft_count が正しいか確認

-- 1. affiliate_cycle の状態確認
SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE total_nft_count > 0
ORDER BY total_nft_count DESC
LIMIT 20;

-- 2. manual_nft_count と total_purchases の整合性確認
SELECT
    ac.user_id,
    u.email,
    u.total_purchases,
    ac.manual_nft_count,
    ac.total_nft_count,
    ac.auto_nft_count,
    -- total_purchases から計算した期待値
    FLOOR(u.total_purchases / 1100) as expected_manual_nft,
    -- 差異確認
    CASE
        WHEN ac.manual_nft_count = FLOOR(u.total_purchases / 1100) THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as status
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.total_nft_count > 0
ORDER BY u.total_purchases DESC
LIMIT 30;

-- 3. 不一致があるユーザー数
SELECT
    COUNT(*) as mismatch_count
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.manual_nft_count != FLOOR(u.total_purchases / 1100);

-- 4. リセット後の状態をシミュレーション
SELECT
    '=== リセット後の状態（シミュレーション） ===' as section;

SELECT
    user_id,
    manual_nft_count as total_nft_count_after_reset,
    0 as auto_nft_count_after_reset,
    0 as cum_usdt_after_reset,
    0 as available_usdt_after_reset,
    'USDT' as phase_after_reset
FROM affiliate_cycle
WHERE manual_nft_count > 0
ORDER BY manual_nft_count DESC
LIMIT 20;

-- 5. リセット後に日利対象となるユーザー数
SELECT
    COUNT(*) as users_eligible_for_yield
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.manual_nft_count > 0
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE;
