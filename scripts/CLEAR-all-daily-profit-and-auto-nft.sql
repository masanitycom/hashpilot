-- ========================================
-- 全ての日利データと自動NFTをクリア
-- ========================================

-- 1. 削除前の状態を確認
SELECT '削除前の状態' as section;

SELECT
    'nft_daily_profit' as table_name,
    COUNT(*) as record_count,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM nft_daily_profit;

SELECT
    'user_daily_profit（ビュー）' as table_name,
    COUNT(*) as record_count,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM user_daily_profit;

SELECT
    '自動NFT' as table_name,
    COUNT(*) as nft_count,
    SUM(CASE WHEN buyback_date IS NULL THEN 1 ELSE 0 END) as active_count
FROM nft_master
WHERE nft_type = 'auto';

SELECT
    'daily_yield_log' as table_name,
    COUNT(*) as record_count
FROM daily_yield_log;

-- 2. 削除実行
-- nft_daily_profitを全削除
DELETE FROM nft_daily_profit;

-- daily_yield_logを全削除
DELETE FROM daily_yield_log;

-- 自動NFTを全削除
DELETE FROM nft_master
WHERE nft_type = 'auto';

-- 自動購入レコードを削除
DELETE FROM purchases
WHERE is_auto_purchase = true;

-- affiliate_cycleをリセット（手動NFTのみ残す、報酬もクリア）
UPDATE affiliate_cycle
SET
    auto_nft_count = 0,
    total_nft_count = manual_nft_count,
    cum_usdt = 0,
    available_usdt = 0,
    phase = 'USDT',
    cycle_number = 0,
    last_updated = NOW();

-- 3. 削除後の確認
SELECT '削除後の確認' as section;

SELECT
    'nft_daily_profit' as table_name,
    COUNT(*) as record_count
FROM nft_daily_profit;

SELECT
    'user_daily_profit（ビュー）' as table_name,
    COUNT(*) as record_count
FROM user_daily_profit;

SELECT
    '自動NFT' as table_name,
    COUNT(*) as nft_count
FROM nft_master
WHERE nft_type = 'auto';

SELECT
    'daily_yield_log' as table_name,
    COUNT(*) as record_count
FROM daily_yield_log;

SELECT
    'affiliate_cycle' as table_name,
    SUM(manual_nft_count) as total_manual_nft,
    SUM(auto_nft_count) as total_auto_nft,
    SUM(total_nft_count) as total_nft
FROM affiliate_cycle;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 全ての日利データと自動NFTをクリアしました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '削除内容:';
    RAISE NOTICE '  - nft_daily_profit: 全削除';
    RAISE NOTICE '  - daily_yield_log: 全削除';
    RAISE NOTICE '  - 自動NFT: 全削除';
    RAISE NOTICE '  - 自動購入レコード: 全削除';
    RAISE NOTICE '  - affiliate_cycle: リセット（手動NFTのみ）';
    RAISE NOTICE '';
    RAISE NOTICE 'これでクリーンな状態から運用開始できます';
    RAISE NOTICE '===========================================';
END $$;
