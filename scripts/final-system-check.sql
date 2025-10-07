-- 本日の修正内容の最終チェック
-- 作成日: 2025年10月7日

-- ============================================
-- 1. HOLDフェーズ中の出金制限テスト
-- ============================================

SELECT
    '=== HOLDフェーズ出金制限チェック ===' as check_name;

-- HOLDフェーズのユーザーを確認
SELECT
    user_id,
    phase,
    cum_usdt,
    available_usdt,
    CASE
        WHEN phase = 'HOLD' AND cum_usdt >= 1100 THEN '⚠️ 出金不可（正常）'
        WHEN phase = 'USDT' AND available_usdt >= 100 THEN '✅ 出金可能'
        ELSE '📊 その他'
    END as withdrawal_status
FROM affiliate_cycle
WHERE (phase = 'HOLD' AND cum_usdt >= 1100)
   OR (phase = 'USDT' AND available_usdt >= 100)
ORDER BY cum_usdt DESC
LIMIT 5;

-- ============================================
-- 2. ペガサス保留者の月次出金除外チェック
-- ============================================

SELECT
    '=== ペガサス保留者チェック ===' as check_name;

-- ペガサス保留者がいるか確認
SELECT
    user_id,
    email,
    is_pegasus_exchange,
    pegasus_withdrawal_unlock_date,
    CASE
        WHEN is_pegasus_exchange = TRUE
             AND (pegasus_withdrawal_unlock_date IS NULL OR CURRENT_DATE < pegasus_withdrawal_unlock_date)
        THEN '🔒 出金制限中'
        ELSE '✅ 制限なし'
    END as restriction_status
FROM users
WHERE is_pegasus_exchange = TRUE
LIMIT 5;

-- ============================================
-- 3. 自動NFT付与機能チェック
-- ============================================

SELECT
    '=== 自動NFT付与システムチェック ===' as check_name;

-- is_auto_purchaseカラムが存在するか確認
SELECT
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'purchases'
  AND column_name = 'is_auto_purchase';

-- 自動購入レコードがあるか確認
SELECT
    COUNT(*) as auto_purchase_count,
    SUM(nft_quantity) as total_auto_nfts
FROM purchases
WHERE is_auto_purchase = true;

-- ============================================
-- 4. NFTサイクル状況の整合性チェック
-- ============================================

SELECT
    '=== NFTサイクル整合性チェック ===' as check_name;

-- affiliate_cycleとnft_masterの整合性確認
SELECT
    ac.user_id,
    ac.total_nft_count as cycle_total,
    ac.manual_nft_count as cycle_manual,
    ac.auto_nft_count as cycle_auto,
    COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_nft_count,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) as actual_manual,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL) as actual_auto,
    CASE
        WHEN ac.total_nft_count = COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as consistency
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
WHERE ac.total_nft_count > 0
GROUP BY ac.user_id, ac.total_nft_count, ac.manual_nft_count, ac.auto_nft_count
HAVING ac.total_nft_count != COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL)
   OR ac.manual_nft_count != COUNT(nm.id) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL)
   OR ac.auto_nft_count != COUNT(nm.id) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL)
LIMIT 10;

-- 不一致がない場合
SELECT
    CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM affiliate_cycle ac
            LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
            WHERE ac.total_nft_count > 0
            GROUP BY ac.user_id, ac.total_nft_count, ac.manual_nft_count, ac.auto_nft_count
            HAVING ac.total_nft_count != COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL)
        )
        THEN '✅ 全ユーザーのNFTカウントが一致しています'
        ELSE '⚠️ 不一致のユーザーがいます（上記参照）'
    END as overall_consistency;

-- ============================================
-- 5. 関数の存在確認
-- ============================================

SELECT
    '=== 重要な関数の存在確認 ===' as check_name;

SELECT
    routine_name,
    CASE
        WHEN routine_name = 'create_withdrawal_request' THEN '✅ 出金申請関数'
        WHEN routine_name = 'process_daily_yield_with_cycles' THEN '✅ 日利計算関数'
        WHEN routine_name = 'process_monthly_auto_withdrawal' THEN '✅ 月次自動出金関数'
        WHEN routine_name = 'get_auto_purchase_history' THEN '✅ 自動購入履歴関数'
        ELSE routine_name
    END as description
FROM information_schema.routines
WHERE routine_name IN (
    'create_withdrawal_request',
    'process_daily_yield_with_cycles',
    'process_monthly_auto_withdrawal',
    'get_auto_purchase_history'
)
ORDER BY routine_name;

-- ============================================
-- 6. システム全体の健全性チェック
-- ============================================

SELECT
    '=== システム全体サマリー ===' as check_name;

SELECT
    (SELECT COUNT(*) FROM users WHERE user_id != '7A9637') as total_users,
    (SELECT COUNT(*) FROM affiliate_cycle WHERE total_nft_count > 0) as users_with_nfts,
    (SELECT SUM(total_nft_count) FROM affiliate_cycle) as total_nfts_in_system,
    (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) as actual_active_nfts,
    (SELECT COUNT(*) FROM affiliate_cycle WHERE phase = 'HOLD' AND cum_usdt >= 1100) as users_in_hold_phase,
    (SELECT COUNT(*) FROM users WHERE is_pegasus_exchange = TRUE) as pegasus_users;

-- ============================================
-- 7. 最終確認メッセージ
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Final System Check Completed';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Please review the results above:';
    RAISE NOTICE '1. HOLD phase withdrawal restriction';
    RAISE NOTICE '2. Pegasus user exclusion';
    RAISE NOTICE '3. Auto NFT grant system';
    RAISE NOTICE '4. NFT cycle consistency';
    RAISE NOTICE '5. Function existence';
    RAISE NOTICE '6. System health summary';
    RAISE NOTICE '===========================================';
END $$;
