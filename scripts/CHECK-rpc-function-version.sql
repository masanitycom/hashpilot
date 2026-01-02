-- ========================================
-- RPC関数バージョン確認
-- ========================================

-- 1. process_daily_yield_v2 関数の定義を確認
SELECT '=== 1. process_daily_yield_v2 関数定義 ===' as section;
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';

-- 2. 関数定義内に total_nft_count + 1 が含まれているか確認
SELECT '=== 2. total_nft_count更新処理の確認 ===' as section;
SELECT
  CASE
    WHEN pg_get_functiondef(oid) LIKE '%total_nft_count = total_nft_count + 1%'
    THEN '✓ total_nft_count + 1 が含まれている（最新版）'
    ELSE '❌ total_nft_count + 1 が含まれていない（古いバージョン）'
  END as version_check
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';

-- 3. 自動NFT付与処理部分の抜粋確認
SELECT '=== 3. 自動NFT付与UPDATE文の確認 ===' as section;
SELECT
  CASE
    WHEN pg_get_functiondef(oid) LIKE '%auto_nft_count = auto_nft_count + 1%'
    THEN '✓ auto_nft_count + 1 あり'
    ELSE '❌ auto_nft_count + 1 なし'
  END as auto_nft_check,
  CASE
    WHEN pg_get_functiondef(oid) LIKE '%total_nft_count = total_nft_count + 1%'
    THEN '✓ total_nft_count + 1 あり'
    ELSE '❌ total_nft_count + 1 なし'
  END as total_nft_check,
  CASE
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 1100%'
    THEN '✓ cum_usdt - 1100 あり'
    ELSE '❌ cum_usdt - 1100 なし'
  END as cum_usdt_check
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';
