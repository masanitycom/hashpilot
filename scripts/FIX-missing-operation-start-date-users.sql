-- ========================================
-- has_approved_nftまたはoperation_start_dateが
-- 未設定のユーザーを修正するスクリプト
-- ========================================
-- 修正日: 2025-12-17
--
-- 問題:
-- - approve_user_nft関数にバグがあり、NFT承認時に
--   has_approved_nftとoperation_start_dateが設定されなかった
-- - そのため、承認済みNFTがあるのに日利が配布されないユーザーがいた
-- ========================================

-- ========================================
-- STEP 1: 問題のあるユーザーを確認
-- ========================================
SELECT
  '【修正前】問題のあるユーザー一覧' as section;

SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count,
  (SELECT MIN(p.admin_approved_at) FROM purchases p WHERE p.user_id = u.user_id AND p.admin_approved = true) as first_approval_date
FROM users u
WHERE
  -- NFTを持っているがhas_approved_nftがfalse、またはoperation_start_dateがnull
  EXISTS (
    SELECT 1 FROM nft_master nm
    WHERE nm.user_id = u.user_id
      AND nm.buyback_date IS NULL
      AND nm.nft_type = 'manual'  -- 手動承認されたNFT
  )
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL OR u.operation_start_date IS NULL)
ORDER BY u.user_id;

-- ========================================
-- STEP 2: has_approved_nftを修正
-- ========================================
SELECT
  '【修正中】has_approved_nftをtrueに設定' as section;

UPDATE users u
SET
  has_approved_nft = true,
  updated_at = NOW()
WHERE
  EXISTS (
    SELECT 1 FROM nft_master nm
    WHERE nm.user_id = u.user_id
      AND nm.buyback_date IS NULL
  )
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL);

SELECT
  COUNT(*) as updated_has_approved_nft_count
FROM users u
WHERE u.has_approved_nft = true
  AND EXISTS (SELECT 1 FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL);

-- ========================================
-- STEP 3: operation_start_dateを修正
-- 最初の承認日から運用開始日を計算
-- ========================================
SELECT
  '【修正中】operation_start_dateを計算して設定' as section;

UPDATE users u
SET
  operation_start_date = calculate_operation_start_date(
    (SELECT MIN(p.admin_approved_at)
     FROM purchases p
     WHERE p.user_id = u.user_id
       AND p.admin_approved = true)
  ),
  updated_at = NOW()
WHERE
  u.operation_start_date IS NULL
  AND EXISTS (
    SELECT 1 FROM purchases p
    WHERE p.user_id = u.user_id
      AND p.admin_approved = true
  );

-- ========================================
-- STEP 4: 修正結果を確認
-- ========================================
SELECT
  '【修正後】修正されたユーザー一覧' as section;

SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count
FROM users u
WHERE
  EXISTS (
    SELECT 1 FROM nft_master nm
    WHERE nm.user_id = u.user_id
      AND nm.buyback_date IS NULL
  )
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
ORDER BY u.operation_start_date DESC
LIMIT 20;

-- ========================================
-- STEP 5: まだ問題が残っているユーザーを確認
-- ========================================
SELECT
  '【確認】まだ問題が残っているユーザー（あれば）' as section;

SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count,
  'NFTあるがフラグ未設定' as problem
FROM users u
WHERE
  EXISTS (
    SELECT 1 FROM nft_master nm
    WHERE nm.user_id = u.user_id
      AND nm.buyback_date IS NULL
  )
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL OR u.operation_start_date IS NULL)
ORDER BY u.user_id;

-- ========================================
-- STEP 6: 12/15運用開始ユーザーの日利配布対象確認
-- ========================================
SELECT
  '【確認】12/15運用開始ユーザーの日利配布対象確認' as section;

SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  u.is_pegasus_exchange,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count,
  CASE
    WHEN u.has_approved_nft = true
         AND u.operation_start_date IS NOT NULL
         AND u.operation_start_date <= CURRENT_DATE
         AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
    THEN '✅ 日利対象'
    ELSE '❌ 対象外'
  END as daily_yield_status
FROM users u
WHERE u.operation_start_date = '2025-12-15'
ORDER BY u.user_id;

-- ========================================
-- サマリー
-- ========================================
SELECT
  '========================================' as separator;
SELECT
  '修正完了サマリー' as section;

SELECT
  '日利対象ユーザー数' as metric,
  COUNT(*) as value
FROM users u
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND EXISTS (SELECT 1 FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL);

SELECT
  '日利対象NFT数' as metric,
  COUNT(*) as value
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL);
