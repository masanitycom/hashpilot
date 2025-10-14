-- ========================================
-- 日利、自動NFT、報酬をクリア
-- ========================================
-- 目的: テストデータをクリアして再テスト準備

-- 1. クリア前の状態確認
SELECT
    '1. クリア前: nft_daily_profit' as section,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as users,
    COUNT(DISTINCT date) as dates,
    SUM(daily_profit) as total_profit
FROM nft_daily_profit;

SELECT
    '1. クリア前: daily_yield_log' as section,
    COUNT(*) as total_records,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM daily_yield_log;

SELECT
    '1. クリア前: 自動NFT' as section,
    COUNT(*) as total_auto_nft,
    COUNT(DISTINCT user_id) as users_with_auto_nft
FROM nft_master
WHERE nft_type = 'auto';

SELECT
    '1. クリア前: 自動購入レコード' as section,
    COUNT(*) as total_auto_purchases,
    COUNT(DISTINCT user_id) as users
FROM purchases
WHERE is_auto_purchase = true;

SELECT
    '1. クリア前: affiliate_cycle' as section,
    COUNT(*) as total_users,
    SUM(auto_nft_count) as total_auto_nft,
    SUM(cum_usdt) as total_cum_usdt,
    SUM(available_usdt) as total_available_usdt,
    COUNT(*) FILTER (WHERE phase = 'HOLD') as users_in_hold_phase
FROM affiliate_cycle;

-- 2. nft_daily_profitをクリア
DELETE FROM nft_daily_profit;

-- 3. daily_yield_logをクリア
DELETE FROM daily_yield_log;

-- 4. 自動NFTを削除
DELETE FROM nft_master WHERE nft_type = 'auto';

-- 5. 自動購入レコードを削除
DELETE FROM purchases WHERE is_auto_purchase = true;

-- 6. affiliate_cycleをリセット（報酬と自動NFTカウントのみ）
UPDATE affiliate_cycle
SET
    auto_nft_count = 0,
    total_nft_count = manual_nft_count,  -- 手動NFTのみ残す
    cum_usdt = 0,
    available_usdt = 0,
    phase = 'USDT',
    cycle_number = 0,
    last_updated = NOW();

-- 7. クリア後の状態確認
SELECT
    '7. クリア後: nft_daily_profit' as section,
    COUNT(*) as total_records
FROM nft_daily_profit;

SELECT
    '7. クリア後: daily_yield_log' as section,
    COUNT(*) as total_records
FROM daily_yield_log;

SELECT
    '7. クリア後: 自動NFT' as section,
    COUNT(*) as total_auto_nft
FROM nft_master
WHERE nft_type = 'auto';

SELECT
    '7. クリア後: 自動購入レコード' as section,
    COUNT(*) as total_auto_purchases
FROM purchases
WHERE is_auto_purchase = true;

SELECT
    '7. クリア後: affiliate_cycle' as section,
    COUNT(*) as total_users,
    SUM(manual_nft_count) as manual_nft,
    SUM(auto_nft_count) as auto_nft,
    SUM(total_nft_count) as total_nft,
    SUM(cum_usdt) as total_cum_usdt,
    SUM(available_usdt) as total_available_usdt,
    COUNT(*) FILTER (WHERE phase = 'HOLD') as users_in_hold_phase
FROM affiliate_cycle;

-- 8. 手動NFT数の整合性確認
SELECT
    '8. 手動NFT整合性確認' as section,
    (SELECT COUNT(*) FROM nft_master WHERE nft_type = 'manual' AND buyback_date IS NULL) as actual_manual_nft,
    (SELECT SUM(manual_nft_count) FROM affiliate_cycle) as recorded_manual_nft,
    (SELECT COUNT(*) FROM nft_master WHERE nft_type = 'manual' AND buyback_date IS NULL) -
    (SELECT SUM(manual_nft_count) FROM affiliate_cycle) as difference;

-- 完了メッセージ
SELECT '✅ 日利、自動NFT、報酬をクリアしました。テスト準備完了。' as status;
