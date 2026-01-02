-- ========================================
-- 59C23C total_nft_count 修正
-- ========================================
-- 問題: nft_masterには2件（manual + auto）あるが、
--       total_nft_countは1のまま

-- 修正前確認
SELECT '=== 修正前 ===' as section;
SELECT
  user_id,
  auto_nft_count,
  manual_nft_count,
  total_nft_count,
  'nft_master件数' as label
FROM affiliate_cycle
WHERE user_id = '59C23C';

SELECT
  COUNT(*) as nft_master_count
FROM nft_master
WHERE user_id = '59C23C' AND buyback_date IS NULL;

-- 修正実行
UPDATE affiliate_cycle
SET total_nft_count = auto_nft_count + manual_nft_count
WHERE user_id = '59C23C';

-- 修正後確認
SELECT '=== 修正後 ===' as section;
SELECT
  user_id,
  auto_nft_count,
  manual_nft_count,
  total_nft_count,
  auto_nft_count + manual_nft_count as expected
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- ========================================
-- 他にも同様の不整合がないか確認
-- ========================================
SELECT '=== 他の不整合ユーザー ===' as section;
SELECT
  ac.user_id,
  ac.auto_nft_count,
  ac.manual_nft_count,
  ac.total_nft_count,
  ac.auto_nft_count + ac.manual_nft_count as expected,
  nm.actual_count
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, COUNT(*) as actual_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm ON ac.user_id = nm.user_id
WHERE ac.total_nft_count != ac.auto_nft_count + ac.manual_nft_count
   OR ac.total_nft_count != COALESCE(nm.actual_count, 0);
