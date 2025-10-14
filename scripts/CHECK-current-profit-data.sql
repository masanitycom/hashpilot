-- ========================================
-- 現在の利益データを確認
-- ========================================

-- 1. 日利ログ
SELECT
    '日利ログ' as section,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

-- 2. NFT日利データ（最新5件）
SELECT
    'NFT日利データ（最新）' as section,
    user_id,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit
GROUP BY user_id, date
ORDER BY date DESC, user_id
LIMIT 10;

-- 3. ユーザー日利ビュー（最新5件）
SELECT
    'ユーザー日利ビュー（最新）' as section,
    user_id,
    date,
    daily_profit
FROM user_daily_profit
ORDER BY date DESC, user_id
LIMIT 10;

-- 4. affiliate_cycleの状態
SELECT
    'affiliate_cycle（サンプル）' as section,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt as 紹介報酬累積,
    available_usdt as 出金可能額,
    phase,
    cycle_number
FROM affiliate_cycle
WHERE total_nft_count > 0
ORDER BY user_id
LIMIT 5;

-- 5. 自動NFTの有無
SELECT
    '自動NFT' as section,
    COUNT(*) as auto_nft_count,
    SUM(nft_value) as total_value
FROM nft_master
WHERE nft_type = 'auto'
  AND buyback_date IS NULL;

-- 6. 特定ユーザーの詳細（テストアカウント 7E0A1E）
SELECT
    '7E0A1Eの詳細' as section;

SELECT
    'NFTマスター' as table_name,
    nft_type,
    nft_sequence,
    nft_value,
    acquired_date
FROM nft_master
WHERE user_id = '7E0A1E'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

SELECT
    '日利データ' as table_name,
    date,
    COUNT(*) as nft_count,
    SUM(daily_profit) as daily_profit_total
FROM nft_daily_profit
WHERE user_id = '7E0A1E'
GROUP BY date
ORDER BY date DESC;

SELECT
    'affiliate_cycle' as table_name,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7E0A1E';
