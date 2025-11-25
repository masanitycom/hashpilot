-- ========================================
-- auto_nft_countがNULLのユーザーを確認
-- ========================================
-- 実行環境: テスト環境 Supabase SQL Editor
-- ========================================

-- 1. affiliate_cycleでauto_nft_countがNULLのユーザー
SELECT
  user_id,
  cum_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE auto_nft_count IS NULL
ORDER BY cum_usdt DESC;

-- 2. cum_usdt >= 2200でauto_nft_countがNULLのユーザー（エラー対象）
SELECT
  user_id,
  cum_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE cum_usdt >= 2200
  AND auto_nft_count IS NULL;

-- 3. 全ユーザーのauto_nft_countの状態
SELECT
  CASE
    WHEN auto_nft_count IS NULL THEN 'NULL'
    WHEN auto_nft_count = 0 THEN 'ZERO'
    ELSE 'HAS_VALUE'
  END as status,
  COUNT(*) as count,
  MIN(cum_usdt) as min_cum_usdt,
  MAX(cum_usdt) as max_cum_usdt
FROM affiliate_cycle
GROUP BY status
ORDER BY status;
