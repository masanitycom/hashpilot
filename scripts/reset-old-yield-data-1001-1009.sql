-- 10/1～10/9の古い方式の日利データをリセット
-- 作成日: 2025年10月9日
-- 目的: RPC関数を使わずに設定した日利データを削除し、再設定可能にする

SELECT '=== リセット前の状態確認 ===' as section;

-- 削除対象期間の日利ログ
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date >= '2025-10-01' AND date <= '2025-10-09'
ORDER BY date;

-- 削除対象期間の日次利益レコード数
SELECT
    COUNT(*) as total_records,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 削除対象期間のNFT単位利益レコード数
SELECT
    COUNT(*) as nft_profit_records
FROM nft_daily_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 紹介報酬レコード数（もしあれば）
SELECT
    COUNT(*) as referral_records,
    SUM(profit_amount) as total_referral
FROM user_referral_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 現在のaffiliate_cycle状態
SELECT
    COUNT(*) as total_users,
    SUM(total_nft_count) as total_nfts,
    SUM(manual_nft_count) as manual_nfts,
    SUM(auto_nft_count) as auto_nfts,
    SUM(available_usdt) as total_available,
    SUM(cum_usdt) as total_cum
FROM affiliate_cycle;

SELECT '=== STEP 1: 10/1～10/9の日利データを削除 ===' as section;

-- 日次利益を削除
DELETE FROM user_daily_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- NFT単位の日次利益を削除
DELETE FROM nft_daily_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 紹介報酬を削除（この期間のもの）
DELETE FROM user_referral_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 日利ログを削除
DELETE FROM daily_yield_log
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

SELECT '=== STEP 2: Affiliate Cycleをリセット ===' as section;

-- 全ユーザーのAffiliate Cycleをリセット（手動NFTのみ残す）
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

SELECT '=== STEP 3: 自動付与NFTを削除 ===' as section;

-- 10/1～10/9に自動付与されたNFTを全て削除
DELETE FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2025-10-01'
  AND acquired_date <= '2025-10-09';

-- 自動購入レコードを削除（この期間のもの）
DELETE FROM purchases
WHERE is_auto_purchase = true
  AND created_at >= '2025-10-01'
  AND created_at <= '2025-10-09';

SELECT '=== リセット後の状態確認 ===' as section;

-- 削除後の日利ログ（0件になるはず）
SELECT
    COUNT(*) as remaining_yield_logs
FROM daily_yield_log
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 削除後の日次利益（0件になるはず）
SELECT
    COUNT(*) as remaining_daily_profit
FROM user_daily_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 削除後のNFT単位利益（0件になるはず）
SELECT
    COUNT(*) as remaining_nft_profit
FROM nft_daily_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 紹介報酬レコード数（0件になるはず）
SELECT
    COUNT(*) as remaining_referral_profit
FROM user_referral_profit
WHERE date >= '2025-10-01' AND date <= '2025-10-09';

-- 自動付与NFTの数（0件になるはず）
SELECT
    COUNT(*) as remaining_auto_nfts
FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2025-10-01'
  AND acquired_date <= '2025-10-09';

-- 現在のaffiliate_cycle状態
SELECT
    COUNT(*) as total_users,
    SUM(total_nft_count) as total_nfts,
    SUM(manual_nft_count) as manual_nfts,
    SUM(auto_nft_count) as auto_nfts,
    SUM(available_usdt) as total_available,
    SUM(cum_usdt) as total_cum
FROM affiliate_cycle;

-- 手動NFTのみのユーザー一覧（上位20件）
SELECT
    ac.user_id,
    u.email,
    ac.total_nft_count as manual_nfts,
    ac.auto_nft_count as auto_nfts,
    ac.available_usdt,
    ac.cum_usdt,
    ac.phase
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
BEGIN
    SELECT COUNT(*) INTO v_remaining_users FROM users;
    SELECT SUM(total_nft_count) INTO v_remaining_nfts FROM affiliate_cycle;

    RAISE NOTICE '===========================================';;
    RAISE NOTICE '✅ 10/1～10/9の日利データリセット完了';
    RAISE NOTICE '===========================================';;
    RAISE NOTICE '削除内容:';
    RAISE NOTICE '  ✅ 10/1～10/9の日次利益データ（user_daily_profit）';
    RAISE NOTICE '  ✅ 10/1～10/9の紹介報酬データ（user_referral_profit）';
    RAISE NOTICE '  ✅ 10/1～10/9のNFT単位利益（nft_daily_profit）';
    RAISE NOTICE '  ✅ 10/1～10/9の自動付与NFT（nft_master）';
    RAISE NOTICE '  ✅ 10/1～10/9の自動購入レコード（purchases）';
    RAISE NOTICE '  ✅ 10/1～10/9の日利ログ（daily_yield_log）';
    RAISE NOTICE '';
    RAISE NOTICE 'リセット内容（全ユーザー）:';
    RAISE NOTICE '  ✅ total_nft_count = manual_nft_count（手動NFTのみ残す）';
    RAISE NOTICE '  ✅ auto_nft_count = 0';
    RAISE NOTICE '  ✅ cum_usdt = 0';
    RAISE NOTICE '  ✅ available_usdt = 0';
    RAISE NOTICE '  ✅ phase = USDT';
    RAISE NOTICE '  ✅ cycle_number = 0';
    RAISE NOTICE '';
    RAISE NOTICE '残存データ:';
    RAISE NOTICE '  - 全ユーザー数: %', v_remaining_users;
    RAISE NOTICE '  - 手動NFT数: %', COALESCE(v_remaining_nfts, 0);
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. 新しいRPC関数を使って10/1から日利を再設定';
    RAISE NOTICE '  2. 紹介報酬とNFT自動付与が正しく動作することを確認';
    RAISE NOTICE '===========================================';;
END $$;
