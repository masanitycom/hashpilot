-- ========================================
-- 現在デプロイされているRPC関数の確認
-- ========================================

-- 1. process_daily_yield_v2 の cum_usdt 減算値を確認
SELECT '=== process_daily_yield_v2 のcum_usdt減算 ===' as section;
SELECT 
  CASE 
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 2200%' THEN '✓ 正しい: cum_usdt - 2200'
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 1100%' THEN '❌ バグ: cum_usdt - 1100'
    ELSE '? 不明'
  END as status
FROM pg_proc
WHERE proname = 'process_daily_yield_v2'
LIMIT 1;

-- 2. process_monthly_referral_reward の cum_usdt 減算値を確認
SELECT '=== process_monthly_referral_reward のcum_usdt減算 ===' as section;
SELECT 
  CASE 
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 2200%' THEN '✓ 正しい: cum_usdt - 2200'
    WHEN pg_get_functiondef(oid) LIKE '%cum_usdt = cum_usdt - 1100%' THEN '❌ バグ: cum_usdt - 1100'
    ELSE '? 不明'
  END as status
FROM pg_proc
WHERE proname = 'process_monthly_referral_reward'
LIMIT 1;

-- 3. 両関数のWHILEループ有無を確認
SELECT '=== WHILEループの有無 ===' as section;
SELECT 
  proname,
  CASE 
    WHEN pg_get_functiondef(oid) LIKE '%WHILE%cum_usdt%2200%LOOP%' THEN '✓ WHILEループあり'
    ELSE '❌ WHILEループなし（1回のみ処理）'
  END as loop_status
FROM pg_proc
WHERE proname IN ('process_daily_yield_v2', 'process_monthly_referral_reward');
