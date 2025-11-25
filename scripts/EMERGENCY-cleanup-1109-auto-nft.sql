-- ========================================
-- 緊急: 11/9に誤って作成されたNFTを削除
-- ========================================
-- 実行環境: テスト環境 Supabase SQL Editor
-- ========================================

BEGIN;

-- 1. 削除対象を確認
SELECT '削除対象NFT:' as step;
SELECT user_id, nft_sequence, acquired_date, created_at
FROM nft_master
WHERE nft_type = 'auto' AND acquired_date = '2025-11-09';

SELECT '削除対象購入レコード:' as step;
SELECT user_id, amount_usd, created_at
FROM purchases
WHERE is_auto_purchase = true AND created_at::date = '2025-11-09';

-- 2. 影響を受けるユーザーのaffiliate_cycleを記録
CREATE TEMP TABLE affected_users AS
SELECT DISTINCT
  nm.user_id,
  COUNT(*) as nft_count,
  ac.auto_nft_count as current_auto_count,
  ac.total_nft_count as current_total_count,
  ac.cum_usdt as current_cum_usdt,
  ac.available_usdt as current_available_usdt
FROM nft_master nm
JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.nft_type = 'auto' AND nm.acquired_date = '2025-11-09'
GROUP BY nm.user_id, ac.auto_nft_count, ac.total_nft_count, ac.cum_usdt, ac.available_usdt;

SELECT '影響を受けるユーザー:' as step;
SELECT * FROM affected_users;

-- 3. affiliate_cycleを巻き戻す
UPDATE affiliate_cycle ac
SET
  cum_usdt = cum_usdt + (au.nft_count * 2200),
  available_usdt = available_usdt - (au.nft_count * 1100),
  auto_nft_count = auto_nft_count - au.nft_count,
  total_nft_count = total_nft_count - au.nft_count,
  phase = CASE WHEN (cum_usdt + (au.nft_count * 2200)) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
  updated_at = NOW()
FROM affected_users au
WHERE ac.user_id = au.user_id;

-- 4. purchasesから削除
DELETE FROM purchases
WHERE is_auto_purchase = true
  AND created_at::date = '2025-11-09';

-- 5. nft_masterから削除
DELETE FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date = '2025-11-09';

-- 6. 確認
SELECT '削除完了後の確認:' as step;
SELECT COUNT(*) as remaining_auto_nft_on_1109
FROM nft_master
WHERE nft_type = 'auto' AND acquired_date = '2025-11-09';

COMMIT;

SELECT '✅ 11/9の誤NFTを削除し、affiliate_cycleを巻き戻しました' as status;
