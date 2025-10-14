-- ========================================
-- 7E0A1Eの日利データを確認
-- ========================================

-- 1. nft_daily_profitに7E0A1Eのデータがあるか
SELECT
    'nft_daily_profit' as table_name,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE user_id = '7E0A1E'
GROUP BY date
ORDER BY date DESC;

-- 2. user_daily_profitビューで7E0A1Eのデータが見えるか
SELECT
    'user_daily_profit (VIEW)' as table_name,
    date,
    daily_profit
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date DESC;

-- 3. 7E0A1EのNFT一覧（買い取り済み除外）
SELECT
    'nft_master' as table_name,
    id as nft_id,
    nft_type,
    nft_sequence,
    nft_value,
    acquired_date
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

-- 4. 10/1の日利データが601枚分あるか確認
SELECT
    '10/1の日利詳細' as section,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit
FROM nft_daily_profit
WHERE user_id = '7E0A1E'
  AND date = '2025-10-01';

-- 5. affiliate_cycleとの整合性チェック
SELECT
    '整合性チェック' as section,
    ac.total_nft_count as affiliate_nft_count,
    COUNT(nm.id) as actual_nft_count,
    ac.available_usdt as current_available_usdt,
    COALESCE(SUM(ndp.daily_profit), 0) as total_daily_profit_10_1
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN nft_daily_profit ndp ON ac.user_id = ndp.user_id AND ndp.date = '2025-10-01'
WHERE ac.user_id = '7E0A1E'
GROUP BY ac.user_id, ac.total_nft_count, ac.available_usdt;

-- 6. 自動NFTの付与履歴
SELECT
    '自動購入履歴' as section,
    nft_quantity,
    amount_usd,
    admin_approved_at,
    cycle_number_at_purchase
FROM purchases
WHERE user_id = '7E0A1E'
  AND is_auto_purchase = true
ORDER BY admin_approved_at DESC;
