-- 7E0A1Eユーザーの出金テスト前のバックアップと復元スクリプト
-- 作成日: 2025年10月8日

-- ============================================
-- STEP 1: 現在の状態を確認・記録
-- ============================================

SELECT '=== 出金テスト前の状態（7E0A1E） ===' as section;

-- affiliate_cycleの状態
SELECT
    'affiliate_cycle' as table_name,
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    cycle_number
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- nft_masterの状態
SELECT
    'nft_master' as table_name,
    user_id,
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date,
    buyback_date
FROM nft_master
WHERE user_id = '7E0A1E'
ORDER BY nft_sequence;

-- usersテーブルの状態
SELECT
    'users' as table_name,
    user_id,
    coinw_uid,
    total_purchases
FROM users
WHERE user_id = '7E0A1E';

-- ============================================
-- STEP 2: 出金テスト後の復元スクリプト（実行用）
-- ============================================

-- この部分は出金テスト後に実行してください

/*
-- affiliate_cycleを元に戻す
UPDATE affiliate_cycle
SET
    manual_nft_count = 600,
    auto_nft_count = 1,
    total_nft_count = 601,
    cum_usdt = 0,  -- 実際の値に置き換え
    available_usdt = 0,  -- 実際の値に置き換え
    phase = 'USDT',  -- 実際の値に置き換え
    cycle_number = 1,  -- 実際の値に置き換え
    last_updated = NOW()
WHERE user_id = '7E0A1E';

-- nft_masterのbuyback_dateをクリア（買い戻し取り消し）
UPDATE nft_master
SET
    buyback_date = NULL,
    updated_at = NOW()
WHERE user_id = '7E0A1E'
  AND buyback_date IS NOT NULL;

-- 出金申請レコードを削除（テストデータ）
DELETE FROM withdrawals
WHERE user_id = '7E0A1E'
  AND created_at > '2025-10-08 00:00:00';

-- 買い取り申請レコードを削除（テストデータ）
DELETE FROM buyback_requests
WHERE user_id = '7E0A1E'
  AND created_at > '2025-10-08 00:00:00';

-- 確認
SELECT
    '=== 復元後の確認 ===' as section,
    ac.user_id,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.total_nft_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) as nft_master_manual,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL) as nft_master_auto,
    COUNT(*) FILTER (WHERE nm.buyback_date IS NULL) as nft_master_total
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
WHERE ac.user_id = '7E0A1E'
GROUP BY ac.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count;
*/

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '7E0A1E 出金テスト用バックアップ';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '上記の状態を記録しました';
    RAISE NOTICE '';
    RAISE NOTICE '出金テスト後の復元方法:';
    RAISE NOTICE '1. このスクリプトのコメント部分を確認';
    RAISE NOTICE '2. 実際の値を確認して復元スクリプトを実行';
    RAISE NOTICE '=========================================';
END $$;
