-- ========================================
-- 7E0A1Eの個人配当が0になる問題を調査
-- ========================================

-- 1. nft_daily_profitに7E0A1Eのデータがあるか
SELECT
    '1. nft_daily_profit（7E0A1E）' as section,
    date,
    COUNT(DISTINCT nft_id) as nft_count,
    SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE user_id = '7E0A1E'
GROUP BY date
ORDER BY date;

-- 2. user_daily_profitビューで7E0A1Eが見えるか
SELECT
    '2. user_daily_profit VIEW（7E0A1E）' as section,
    date,
    daily_profit
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date;

-- 3. 7E0A1EのNFT一覧（アクティブのみ）
SELECT
    '3. NFTマスター（7E0A1E）' as section,
    nft_type,
    COUNT(*) as nft_count,
    SUM(nft_value) as total_value
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL
GROUP BY nft_type;

-- 4. affiliate_cycleの状態
SELECT
    '4. affiliate_cycle（7E0A1E）' as section,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    cycle_number
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 5. 10/1の詳細な計算確認
SELECT
    '5. 10/1の計算詳細' as section,
    nm.nft_type,
    COUNT(nm.id) as nft_count,
    COUNT(ndp.nft_id) as profit_record_count,
    SUM(ndp.daily_profit) as total_profit
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id AND ndp.date = '2025-10-01'
WHERE nm.user_id = '7E0A1E'
  AND nm.buyback_date IS NULL
GROUP BY nm.nft_type;

-- 6. 自動購入のタイミング確認
SELECT
    '6. 自動購入履歴' as section,
    nft_quantity,
    amount_usd,
    admin_approved_at,
    cycle_number_at_purchase
FROM purchases
WHERE user_id = '7E0A1E'
  AND is_auto_purchase = true
ORDER BY admin_approved_at;

-- 7. 自動NFTの取得日を確認
SELECT
    '7. 自動NFTの取得日' as section,
    nft_sequence,
    nft_value,
    acquired_date,
    created_at
FROM nft_master
WHERE user_id = '7E0A1E'
  AND nft_type = 'auto'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

-- 8. 比較：正常なユーザー（自動購入なし）
SELECT
    '8. 正常ユーザーのサンプル' as section,
    user_id,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-10-01'
  AND user_id != '7E0A1E'
GROUP BY user_id
ORDER BY total_profit DESC
LIMIT 3;
