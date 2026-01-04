-- ========================================
-- 3194C4の解約状態確認
-- ========================================

SELECT
  user_id,
  email,
  is_active_investor,
  has_approved_nft,
  total_purchases,
  operation_start_date
FROM users
WHERE user_id = '3194C4';

-- nft_masterの状態
SELECT
  id,
  user_id,
  nft_type,
  acquired_date,
  buyback_date
FROM nft_master
WHERE user_id = '3194C4';
