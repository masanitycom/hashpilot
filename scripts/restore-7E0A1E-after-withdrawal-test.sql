-- 7E0A1Eユーザーの出金テスト後の復元スクリプト
-- 実行日: 出金テスト後に実行してください

-- ============================================
-- 出金テスト前の状態（バックアップ情報）
-- ============================================
-- affiliate_cycle:
--   manual_nft_count: 600
--   auto_nft_count: 1
--   total_nft_count: 601
--   cum_usdt: (出金テスト前の値)
--   available_usdt: (出金テスト前の値)
--   phase: (出金テスト前の値)
--   cycle_number: (出金テスト前の値)
--
-- nft_master:
--   手動NFT: 600枚 (sequence 1-600)
--   自動NFT: 1枚 (sequence 1)
--
-- users:
--   total_purchases: 660000.00
--   coinw_uid: 12345678

-- ============================================
-- STEP 1: 出金申請・買い取り申請を削除（テストデータ）
-- ============================================

-- 今日作成された出金申請を削除
DELETE FROM withdrawals
WHERE user_id = '7E0A1E'
  AND created_at >= '2025-10-08 00:00:00';

-- 今日作成された買い取り申請を削除
DELETE FROM buyback_requests
WHERE user_id = '7E0A1E'
  AND created_at >= '2025-10-08 00:00:00';

-- ============================================
-- STEP 2: nft_masterを復元
-- ============================================

-- 買い戻し済みNFTを元に戻す（buyback_dateをクリア）
UPDATE nft_master
SET
    buyback_date = NULL,
    updated_at = NOW()
WHERE user_id = '7E0A1E'
  AND buyback_date IS NOT NULL;

-- NFTが削除されていた場合は再作成が必要
-- （通常は buyback_date をクリアするだけで十分）

-- ============================================
-- STEP 3: affiliate_cycleを復元
-- ============================================

UPDATE affiliate_cycle
SET
    manual_nft_count = 600,
    auto_nft_count = 1,
    total_nft_count = 601,
    last_updated = NOW()
    -- cum_usdt, available_usdt, phase, cycle_numberは
    -- 出金テスト前の値がわかれば個別に設定してください
WHERE user_id = '7E0A1E';

-- ============================================
-- STEP 4: 復元結果の確認
-- ============================================

SELECT '=== 復元後の確認 ===' as section;

-- NFTデータ整合性チェック
SELECT
    ac.user_id,
    ac.manual_nft_count as cycle_manual,
    ac.auto_nft_count as cycle_auto,
    ac.total_nft_count as cycle_total,
    COALESCE(COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL), 0) as master_manual,
    COALESCE(COUNT(*) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL), 0) as master_auto,
    COALESCE(COUNT(*) FILTER (WHERE nm.buyback_date IS NULL), 0) as master_total,
    CASE
        WHEN ac.manual_nft_count = COALESCE(COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL), 0)
            AND ac.auto_nft_count = COALESCE(COUNT(*) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL), 0)
        THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as status
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
WHERE ac.user_id = '7E0A1E'
GROUP BY ac.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count;

-- nft_master詳細確認
SELECT
    '=== NFTマスター確認 ===' as section,
    nft_type,
    COUNT(*) as count,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as available,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as bought_back
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type
ORDER BY nft_type;

-- usersテーブル確認
SELECT
    '=== usersテーブル ===' as section,
    user_id,
    total_purchases,
    coinw_uid
FROM users
WHERE user_id = '7E0A1E';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ 7E0A1E 復元完了';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '確認内容:';
    RAISE NOTICE '  - 出金申請・買い取り申請削除';
    RAISE NOTICE '  - NFTマスターの買い戻し取り消し';
    RAISE NOTICE '  - affiliate_cycleの復元';
    RAISE NOTICE '';
    RAISE NOTICE '上記の結果を確認してください';
    RAISE NOTICE '=========================================';
END $$;
