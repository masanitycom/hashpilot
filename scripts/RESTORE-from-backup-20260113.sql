-- ========================================
-- バックアップからの復元スクリプト
-- 実行日: 2026-01-13
-- ========================================
-- ⚠️ 警告: このスクリプトは修正を元に戻します
-- 問題が発生した場合のみ実行してください
-- ========================================

-- ========================================
-- RESTORE 1: 削除した自動NFTを復元
-- ========================================
SELECT '=== RESTORE 1: 自動NFT復元 ===' as section;

INSERT INTO nft_master (
  id, user_id, nft_sequence, nft_type, nft_value,
  acquired_date, buyback_date, operation_start_date, created_at, updated_at
)
SELECT
  id, user_id, nft_sequence, nft_type, nft_value,
  acquired_date, buyback_date, operation_start_date, created_at, updated_at
FROM backup_nft_master_20260113
ON CONFLICT (id) DO NOTHING;

SELECT '復元した自動NFT' as restore_type, COUNT(*) as records FROM backup_nft_master_20260113;

-- ========================================
-- RESTORE 2: 削除したpurchasesを復元
-- ========================================
SELECT '=== RESTORE 2: purchases復元 ===' as section;

INSERT INTO purchases (
  id, user_id, amount_usd, admin_approved, is_auto_purchase,
  created_at, updated_at, cycle_number_at_purchase
)
SELECT
  id, user_id, amount_usd, admin_approved, is_auto_purchase,
  created_at, updated_at, cycle_number_at_purchase
FROM backup_purchases_20260113
ON CONFLICT (id) DO NOTHING;

SELECT '復元したpurchases' as restore_type, COUNT(*) as records FROM backup_purchases_20260113;

-- ========================================
-- RESTORE 3: affiliate_cycleを復元
-- ========================================
SELECT '=== RESTORE 3: affiliate_cycle復元 ===' as section;

-- 全レコードを削除して復元
TRUNCATE affiliate_cycle;

INSERT INTO affiliate_cycle (
  id, user_id, cum_usdt, available_usdt, phase,
  auto_nft_count, manual_nft_count, total_nft_count,
  withdrawn_referral_usdt, created_at, updated_at
)
SELECT
  id, user_id, cum_usdt, available_usdt, phase,
  auto_nft_count, manual_nft_count, total_nft_count,
  withdrawn_referral_usdt, created_at, updated_at
FROM backup_affiliate_cycle_20260113;

SELECT '復元したaffiliate_cycle' as restore_type, COUNT(*) as records FROM backup_affiliate_cycle_20260113;

-- ========================================
-- RESTORE 4: 1月の日次紹介報酬データを復元
-- ========================================
SELECT '=== RESTORE 4: 1月日次紹介報酬復元 ===' as section;

INSERT INTO user_referral_profit (
  id, user_id, date, referral_level, child_user_id,
  profit_amount, created_at
)
SELECT
  id, user_id, date, referral_level, child_user_id,
  profit_amount, created_at
FROM backup_user_referral_profit_jan_20260113
ON CONFLICT (id) DO NOTHING;

SELECT '復元した1月日次紹介報酬' as restore_type, COUNT(*) as records FROM backup_user_referral_profit_jan_20260113;

-- ========================================
-- 復元完了確認
-- ========================================
SELECT '=== 復元完了確認 ===' as section;

SELECT 'nft_master (auto, 1月)' as table_name, COUNT(*) as records
FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2026-01-01'
UNION ALL
SELECT 'affiliate_cycle' as table_name, COUNT(*) as records
FROM affiliate_cycle
UNION ALL
SELECT 'user_referral_profit (1月)' as table_name, COUNT(*) as records
FROM user_referral_profit
WHERE date >= '2026-01-01';

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '復元完了';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'データが修正前の状態に戻りました';
  RAISE NOTICE '========================================';
END $$;
