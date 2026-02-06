-- ========================================
-- NFT自動付与ロジックの所在確認
-- ========================================

-- CLAUDE.mdによると:
-- ・日次処理（process_daily_yield_v2）: NFT自動付与なし
-- ・月末処理（process_monthly_referral_reward）: NFT自動付与あり

-- 1. process_daily_yield_v2 にNFT自動付与があるか
SELECT '=== process_daily_yield_v2 のNFT自動付与 ===' as section;
SELECT 
  CASE 
    WHEN pg_get_functiondef(oid) LIKE '%auto_nft%' THEN '⚠️ auto_nft処理あり'
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt >= 2200%' THEN '⚠️ NFT自動付与トリガーあり'
    ELSE '✓ NFT自動付与なし（正常）'
  END as status
FROM pg_proc
WHERE proname = 'process_daily_yield_v2'
LIMIT 1;

-- 2. process_monthly_referral_reward のNFT自動付与
SELECT '=== process_monthly_referral_reward のNFT自動付与 ===' as section;
SELECT 
  CASE 
    WHEN pg_get_functiondef(oid) LIKE '%auto_nft%' THEN '✓ auto_nft処理あり'
    ELSE '❌ auto_nft処理なし'
  END as status,
  CASE 
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 2200%' THEN '✓ 正しい: -2200'
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 1100%' THEN '❌ バグ: -1100'
    ELSE '? 不明'
  END as subtraction
FROM pg_proc
WHERE proname = 'process_monthly_referral_reward'
LIMIT 1;

-- 3. 関数一覧でNFT自動付与関連を確認
SELECT '=== NFT自動付与に関連する関数 ===' as section;
SELECT proname
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND (proname LIKE '%nft%' OR proname LIKE '%cycle%' OR proname LIKE '%monthly%')
ORDER BY proname;
