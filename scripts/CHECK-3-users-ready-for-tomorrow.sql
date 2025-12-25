-- ========================================
-- 3ユーザーが明日の日利設定に反映されるか確認
-- ========================================

-- 1. 日利配布の対象条件を確認
SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.is_active_investor,
  u.operation_start_date,
  u.is_pegasus_exchange,
  CASE
    WHEN u.has_approved_nft = false THEN '❌ has_approved_nft = false'
    WHEN u.operation_start_date IS NULL THEN '❌ operation_start_date = NULL'
    WHEN u.operation_start_date > CURRENT_DATE THEN '❌ 運用開始前'
    WHEN u.is_pegasus_exchange = true THEN '❌ ペガサス除外'
    ELSE '✅ 対象'
  END as status
FROM users u
WHERE u.user_id IN ('225F87', '20248A', '5A708D');

-- 2. NFT保有状況（buyback_date IS NULLのみカウント）
SELECT
  nm.user_id,
  u.email,
  COUNT(*) as active_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.user_id IN ('225F87', '20248A', '5A708D')
  AND nm.buyback_date IS NULL
GROUP BY nm.user_id, u.email;

-- 3. 総NFT数の確認（日利処理で使用される数）
SELECT
  '総NFT数（日利処理対象）' as info,
  COUNT(*) as total_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL);

-- 4. 3ユーザーのNFTが含まれているか
SELECT
  '3ユーザーのNFTが総数に含まれているか' as info;

SELECT
  nm.user_id,
  u.email,
  nm.id as nft_id,
  CASE
    WHEN u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= CURRENT_DATE
      AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
    THEN '✅ 含まれる'
    ELSE '❌ 除外'
  END as included_in_total
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.user_id IN ('225F87', '20248A', '5A708D')
  AND nm.buyback_date IS NULL;

-- 5. 比較：3ユーザーを含む/含まない場合のNFT数
SELECT
  '3ユーザー除外時' as condition,
  COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND u.user_id NOT IN ('225F87', '20248A', '5A708D')
UNION ALL
SELECT
  '3ユーザー含む時' as condition,
  COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL);
