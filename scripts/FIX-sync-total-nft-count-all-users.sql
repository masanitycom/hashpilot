-- ========================================
-- 全ユーザーのtotal_nft_count同期
-- ========================================
-- 原因: 古いバージョンのRPC関数では
--       total_nft_count の更新が漏れていた

-- 1. 修正前の不整合確認
SELECT '=== 1. 修正前: 不整合ユーザー ===' as section;
SELECT
  ac.user_id,
  ac.auto_nft_count,
  ac.manual_nft_count,
  ac.total_nft_count as current_total,
  ac.auto_nft_count + ac.manual_nft_count as expected_total,
  nm.actual_count as nft_master_count
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, COUNT(*) as actual_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm ON ac.user_id = nm.user_id
WHERE ac.total_nft_count != ac.auto_nft_count + ac.manual_nft_count
ORDER BY ac.user_id;

-- 2. 全ユーザーのtotal_nft_countを同期
UPDATE affiliate_cycle
SET total_nft_count = auto_nft_count + manual_nft_count
WHERE total_nft_count != auto_nft_count + manual_nft_count;

-- 3. 修正後の確認（不整合がないはず）
SELECT '=== 2. 修正後: 不整合確認 ===' as section;
SELECT
  COUNT(*) as mismatch_count
FROM affiliate_cycle
WHERE total_nft_count != auto_nft_count + manual_nft_count;

-- 4. nft_masterとの整合性も確認
SELECT '=== 3. nft_masterとの整合性 ===' as section;
SELECT
  ac.user_id,
  ac.total_nft_count,
  nm.actual_count,
  CASE
    WHEN ac.total_nft_count = COALESCE(nm.actual_count, 0) THEN '✓'
    ELSE '❌ 不一致'
  END as status
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, COUNT(*) as actual_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm ON ac.user_id = nm.user_id
WHERE ac.total_nft_count != COALESCE(nm.actual_count, 0)
ORDER BY ac.user_id;
