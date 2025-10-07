-- テストユーザー7E0A1Eを削除し、7A9637を元の状態に戻す
-- 作成日: 2025年10月7日

SELECT '=== 削除前の状態確認 ===' as section;

-- 7E0A1Eのデータ
SELECT 'users' as table_name, COUNT(*) as count FROM users WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'nft_master', COUNT(*) FROM nft_master WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'purchases', COUNT(*) FROM purchases WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'affiliate_cycle', COUNT(*) FROM affiliate_cycle WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'user_daily_profit', COUNT(*) FROM user_daily_profit WHERE user_id = '7E0A1E';

-- 7A9637の現在の状態
SELECT
    user_id,
    total_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE user_id = '7A9637';

SELECT '=== 7A9637の元の状態（テスト前） ===' as section;

-- テスト前の状態:
-- total_nft_count: 1 (手動)
-- auto_nft_count: 0
-- cum_usdt: 120.98
-- available_usdt: 119.83

SELECT '=== 削除実行 ===' as section;

-- 1. 7E0A1Eの日次利益データを削除
DELETE FROM user_daily_profit WHERE user_id = '7E0A1E';

-- 2. 7E0A1EのNFT日次利益を削除
DELETE FROM nft_daily_profit WHERE user_id = '7E0A1E';

-- 3. 7E0A1EのNFTを削除
DELETE FROM nft_master WHERE user_id = '7E0A1E';

-- 4. 7E0A1Eの購入記録を削除
DELETE FROM purchases WHERE user_id = '7E0A1E';

-- 5. 7E0A1EのAffiliate Cycleを削除
DELETE FROM affiliate_cycle WHERE user_id = '7E0A1E';

-- 6. 7E0A1Eのユーザーを削除
DELETE FROM users WHERE user_id = '7E0A1E';

SELECT '=== 7A9637の自動付与NFTを削除 ===' as section;

-- 今日付与された3個の自動NFTを削除
DELETE FROM nft_master
WHERE user_id = '7A9637'
  AND nft_type = 'auto'
  AND acquired_date = CURRENT_DATE;

-- 今日の自動購入レコードを削除
DELETE FROM purchases
WHERE user_id = '7A9637'
  AND is_auto_purchase = true
  AND admin_approved_at::date = CURRENT_DATE;

SELECT '=== 7A9637を元の状態に復元 ===' as section;

-- 7A9637のAffiliate Cycleを元に戻す
UPDATE affiliate_cycle
SET
    total_nft_count = 1,  -- 手動1個のみ
    manual_nft_count = 1,
    auto_nft_count = 0,   -- 自動0個
    cum_usdt = 120.98,    -- テスト前の値
    available_usdt = 119.83,  -- テスト前の値
    phase = 'USDT',
    last_updated = NOW()
WHERE user_id = '7A9637';

SELECT '=== 削除後の状態確認 ===' as section;

-- 7E0A1Eが完全に削除されたか確認
SELECT 'users' as table_name, COUNT(*) as remaining FROM users WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'nft_master', COUNT(*) FROM nft_master WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'purchases', COUNT(*) FROM purchases WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'affiliate_cycle', COUNT(*) FROM affiliate_cycle WHERE user_id = '7E0A1E'
UNION ALL
SELECT 'user_daily_profit', COUNT(*) FROM user_daily_profit WHERE user_id = '7E0A1E';

-- 7A9637が元に戻ったか確認
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

-- 7A9637のNFT確認
SELECT
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date
FROM nft_master
WHERE user_id = '7A9637'
  AND buyback_date IS NULL
ORDER BY nft_sequence;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ テストユーザー削除完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '削除したユーザー: 7E0A1E';
    RAISE NOTICE '復元したユーザー: 7A9637';
    RAISE NOTICE '';
    RAISE NOTICE '7A9637の状態:';
    RAISE NOTICE '  - 総NFT: 1個（手動）';
    RAISE NOTICE '  - cum_usdt: $120.98';
    RAISE NOTICE '  - available_usdt: $119.83';
    RAISE NOTICE '===========================================';
END $$;
