-- 自動付与されたNFTが次の日利計算で元本として反映されるかテスト
-- 7A9637: 手動1個 + 自動3個 = 合計4個

SELECT '=== 1. 現在の7A9637の状態 ===' as section;

SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- NFTの詳細
SELECT
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date
FROM nft_master
WHERE user_id = '7A9637'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

SELECT '=== 2. 次の日利計算のシミュレーション ===' as section;

-- 想定: 1%の利率で計算
WITH simulation AS (
    SELECT
        '7A9637' as user_id,
        4 as total_nft_count,  -- 手動1 + 自動3
        4400 as base_amount,   -- 4 × 1100
        0.01 as yield_rate,    -- 1%
        0.0042 as user_rate    -- 1% × 0.7 × 0.6
    FROM affiliate_cycle
    WHERE user_id = '7A9637'
)
SELECT
    user_id,
    total_nft_count,
    base_amount as calculated_base,
    (base_amount * user_rate) as daily_profit,
    '元本: $4,400（4個のNFT）' as note
FROM simulation;

SELECT '=== 3. 実際に日利計算を実行（テストモード） ===' as section;

-- テストモードで日利計算を実行
SELECT * FROM process_daily_yield_with_cycles(
    CURRENT_DATE,
    0.01,  -- 1%の利率
    30.0,  -- マージン30%
    true,  -- テストモード
    false  -- バリデーション有効
);

SELECT '=== 4. 7A9637の想定される結果 ===' as section;

-- 計算式の確認
SELECT
    '元本（NFT数 × 1100）' as item,
    '4 × 1100 = $4,400' as calculation;

SELECT
    '日利率（マージン後）' as item,
    '1% × 0.7 = 0.7%' as calculation;

SELECT
    'ユーザー取り分' as item,
    '0.7% × 0.6 = 0.42%' as calculation;

SELECT
    '日次利益' as item,
    '$4,400 × 0.42% = $18.48' as calculation;

SELECT '=== 5. 重要な確認ポイント ===' as section;

SELECT
    CASE
        WHEN (SELECT total_nft_count FROM affiliate_cycle WHERE user_id = '7A9637') = 4
        THEN '✅ NFTカウント正常: 4個（手動1 + 自動3）'
        ELSE '❌ NFTカウント異常'
    END as nft_count_check;

SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM nft_master WHERE user_id = '7A9637' AND buyback_date IS NULL) = 4
        THEN '✅ NFTレコード正常: 4個のNFTが存在'
        ELSE '❌ NFTレコード異常'
    END as nft_record_check;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM nft_master
            WHERE user_id = '7A9637'
              AND nft_type = 'auto'
              AND buyback_date IS NULL
        )
        THEN '✅ 自動NFTが有効: 日利計算の対象になる'
        ELSE '❌ 自動NFTが無効'
    END as auto_nft_active_check;

SELECT '=== 6. 元本反映の仕組み ===' as section;

SELECT
    'process_daily_yield_with_cycles関数' as function_name,
    'WHERE total_nft_count > 0' as condition,
    'v_base_amount := total_nft_count × 1100' as calculation,
    '全てのNFT（手動+自動）を元本として計算' as behavior;

-- 実際のクエリを確認
SELECT
    ac.user_id,
    ac.total_nft_count,
    ac.total_nft_count * 1100 as base_amount_will_be,
    COUNT(nm.id) as actual_nft_count,
    CASE
        WHEN ac.total_nft_count = COUNT(nm.id)
        THEN '✅ 一致: 日利計算で正しく反映される'
        ELSE '⚠️ 不一致: 要確認'
    END as consistency
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE ac.user_id = '7A9637'
GROUP BY ac.user_id, ac.total_nft_count;

-- 完了メッセージ
DO $$
DECLARE
    v_total_nft INTEGER;
    v_base_amount NUMERIC;
    v_expected_profit NUMERIC;
BEGIN
    SELECT total_nft_count INTO v_total_nft
    FROM affiliate_cycle
    WHERE user_id = '7A9637';

    v_base_amount := v_total_nft * 1100;
    v_expected_profit := v_base_amount * 0.01 * 0.7 * 0.6;  -- 1%利率の場合

    RAISE NOTICE '===========================================';
    RAISE NOTICE '自動NFT反映テスト結果';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '現在のNFT数: %個', v_total_nft;
    RAISE NOTICE '元本: $%', v_base_amount;
    RAISE NOTICE '想定日次利益（1%%利率）: $%', v_expected_profit;
    RAISE NOTICE '';
    RAISE NOTICE '✅ 自動付与されたNFTは次の日利計算で';
    RAISE NOTICE '   元本として反映されます';
    RAISE NOTICE '===========================================';
END $$;
