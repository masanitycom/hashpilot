-- 7E0A1Eの自動NFT 2枚の利益状況を確認

SELECT '=== 7E0A1Eの保有NFT ===' as section;

SELECT
    id,
    user_id,
    nft_sequence,
    nft_type,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

SELECT '=== nft_total_profit ビューの確認 ===' as section;

SELECT
    nft_id,
    user_id,
    nft_type,
    nft_value,
    total_profit_for_buyback,
    nft_sequence
FROM nft_total_profit
WHERE user_id = '7E0A1E'
  AND nft_id IN (
    SELECT id FROM nft_master
    WHERE user_id = '7E0A1E' AND buyback_date IS NULL
  );

SELECT '=== 買い取り額計算シミュレーション ===' as section;

SELECT
    nft_id,
    nft_type,
    nft_value as base_value,
    total_profit_for_buyback as nft_profit,
    (nft_value - (total_profit_for_buyback / 2)) as buyback_amount,
    CASE
        WHEN (nft_value - (total_profit_for_buyback / 2)) < 0 THEN 0
        ELSE (nft_value - (total_profit_for_buyback / 2))
    END as final_buyback_amount
FROM nft_total_profit
WHERE user_id = '7E0A1E'
  AND nft_id IN (
    SELECT id FROM nft_master
    WHERE user_id = '7E0A1E' AND buyback_date IS NULL
  );

SELECT '=== 7E0A1Eの日利データ ===' as section;

SELECT
    date,
    daily_profit,
    created_at
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date DESC
LIMIT 10;

SELECT '=== nft_total_profitビューが存在するか ===' as section;

SELECT EXISTS (
    SELECT 1
    FROM information_schema.views
    WHERE table_schema = 'public'
      AND table_name = 'nft_total_profit'
) as view_exists;
