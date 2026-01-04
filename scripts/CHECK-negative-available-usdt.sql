-- ========================================
-- available_usdtがマイナスのユーザーを確認
-- ========================================

SELECT '=== マイナスのavailable_usdt ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase,
  auto_nft_count
FROM affiliate_cycle
WHERE available_usdt < 0
ORDER BY available_usdt;
