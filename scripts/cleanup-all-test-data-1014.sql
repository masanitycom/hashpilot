-- 10/14実行: 全テストデータをクリーンアップ
-- 作成日: 2025年10月7日
-- 目的: テスト期間中に発生した全ての日利、紹介報酬、自動NFT付与をリセット

SELECT '=== クリーンアップ前の状態確認 ===' as section;

-- 全ユーザーの状態
SELECT
    COUNT(*) as total_users,
    SUM(total_nft_count) as total_nfts,
    SUM(auto_nft_count) as total_auto_nfts,
    SUM(available_usdt) as total_available,
    SUM(cum_usdt) as total_cum_usdt
FROM affiliate_cycle;

-- 自動付与NFTの数
SELECT
    COUNT(*) as auto_granted_nfts
FROM nft_master
WHERE nft_type = 'auto';

-- 自動購入レコード数
SELECT
    COUNT(*) as auto_purchase_records
FROM purchases
WHERE is_auto_purchase = true;

-- 日次利益レコード数
SELECT
    COUNT(*) as daily_profit_records
FROM user_daily_profit;

-- 紹介報酬レコード数
SELECT
    COUNT(*) as referral_profit_records,
    SUM(profit_amount) as total_referral_amount
FROM user_referral_profit;

SELECT '=== STEP 1: 日次利益・報酬データを削除 ===' as section;

-- 全ての日次利益を削除
DELETE FROM user_daily_profit;

-- NFT単位の日次利益を削除
DELETE FROM nft_daily_profit;

-- 紹介報酬を削除
DELETE FROM user_referral_profit;

-- 日利ログを削除
DELETE FROM daily_yield_log;

SELECT '=== STEP 2: 自動付与NFTを削除 ===' as section;

-- 自動付与されたNFTを全て削除
DELETE FROM nft_master
WHERE nft_type = 'auto';

-- 自動購入レコードを削除
DELETE FROM purchases
WHERE is_auto_purchase = true;

SELECT '=== STEP 3: Affiliate Cycleをリセット ===' as section;

-- 全ユーザーのAffiliate Cycleをリセット（管理者含む全員）
UPDATE affiliate_cycle
SET
    -- 手動NFTのみ残す
    total_nft_count = manual_nft_count,
    auto_nft_count = 0,
    -- 紹介報酬と利益をリセット
    cum_usdt = 0,
    available_usdt = 0,
    -- フェーズをリセット
    phase = 'USDT',
    -- サイクル番号をリセット
    cycle_number = 0,
    last_updated = NOW();

-- SELECT '=== STEP 4: テストユーザーを削除 ===' as section;
-- ⚠️ テストユーザー削除は保留（まだ実行しない）

-- テストユーザーのリスト確認のみ
SELECT
    user_id,
    email,
    username,
    created_at
FROM users
WHERE email LIKE '%test%' OR email LIKE '%demo%'
ORDER BY created_at;

-- ========== 以下はコメントアウト（テストユーザー削除処理） ==========
-- DELETE FROM user_daily_profit WHERE user_id IN (
--     SELECT user_id FROM users
--     WHERE email LIKE '%test%' OR email LIKE '%demo%'
-- );
--
-- DELETE FROM nft_daily_profit WHERE user_id IN (
--     SELECT user_id FROM users
--     WHERE email LIKE '%test%' OR email LIKE '%demo%'
-- );
--
-- DELETE FROM nft_master WHERE user_id IN (
--     SELECT user_id FROM users
--     WHERE email LIKE '%test%' OR email LIKE '%demo%'
-- );
--
-- DELETE FROM purchases WHERE user_id IN (
--     SELECT user_id FROM users
--     WHERE email LIKE '%test%' OR email LIKE '%demo%'
-- );
--
-- DELETE FROM affiliate_cycle WHERE user_id IN (
--     SELECT user_id FROM users
--     WHERE email LIKE '%test%' OR email LIKE '%demo%'
-- );
--
-- DELETE FROM users WHERE email LIKE '%test%' OR email LIKE '%demo%';

SELECT '=== クリーンアップ後の状態確認 ===' as section;

-- 全ユーザーの状態
SELECT
    COUNT(*) as total_users,
    SUM(total_nft_count) as total_nfts,
    SUM(auto_nft_count) as total_auto_nfts,
    SUM(available_usdt) as total_available,
    SUM(cum_usdt) as total_cum_usdt
FROM affiliate_cycle;

-- 自動付与NFTの数（0になるはず）
SELECT
    COUNT(*) as remaining_auto_nfts
FROM nft_master
WHERE nft_type = 'auto';

-- 自動購入レコード数（0になるはず）
SELECT
    COUNT(*) as remaining_auto_purchases
FROM purchases
WHERE is_auto_purchase = true;

-- 日次利益レコード数（0になるはず）
SELECT
    COUNT(*) as remaining_daily_profit
FROM user_daily_profit;

-- 紹介報酬レコード数（0になるはず）
SELECT
    COUNT(*) as remaining_referral_profit
FROM user_referral_profit;

SELECT '=== 手動NFTのみのユーザー一覧 ===' as section;

SELECT
    ac.user_id,
    u.email,
    ac.total_nft_count as manual_nfts,
    ac.auto_nft_count as auto_nfts,
    ac.available_usdt,
    ac.cum_usdt
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.total_nft_count > 0
ORDER BY ac.total_nft_count DESC
LIMIT 20;

-- 完了メッセージ
DO $$
DECLARE
    v_remaining_users INTEGER;
    v_remaining_nfts INTEGER;
    v_deleted_auto_nfts INTEGER;
BEGIN
    -- 全ユーザー数をカウント
    SELECT COUNT(*) INTO v_remaining_users FROM users;
    SELECT SUM(total_nft_count) INTO v_remaining_nfts FROM affiliate_cycle;

    -- 削除された自動NFT数は実行前に記録する必要がある

    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ テストデータクリーンアップ完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '削除内容:';
    RAISE NOTICE '  ✅ 全ての日次利益データ（user_daily_profit）';
    RAISE NOTICE '  ✅ 全ての紹介報酬データ（user_referral_profit）';
    RAISE NOTICE '  ✅ NFT単位の日次利益（nft_daily_profit）';
    RAISE NOTICE '  ✅ 全ての自動付与NFT（nft_master）';
    RAISE NOTICE '  ✅ 全ての自動購入レコード（purchases）';
    RAISE NOTICE '  ✅ 日利ログデータ（daily_yield_log）';
    RAISE NOTICE '';
    RAISE NOTICE 'リセット内容（管理者含む全員）:';
    RAISE NOTICE '  ✅ total_nft_count = manual_nft_count（手動NFTのみ残す）';
    RAISE NOTICE '  ✅ auto_nft_count = 0';
    RAISE NOTICE '  ✅ cum_usdt = 0';
    RAISE NOTICE '  ✅ available_usdt = 0';
    RAISE NOTICE '  ✅ phase = USDT';
    RAISE NOTICE '  ✅ cycle_number = 0';
    RAISE NOTICE '';
    RAISE NOTICE '保留:';
    RAISE NOTICE '  ⚠️ テストユーザー削除は保留（リスト確認のみ実行）';
    RAISE NOTICE '';
    RAISE NOTICE '残存データ:';
    RAISE NOTICE '  - 全ユーザー数: %', v_remaining_users;
    RAISE NOTICE '  - 手動NFT数: %', COALESCE(v_remaining_nfts, 0);
    RAISE NOTICE '===========================================';
END $$;
