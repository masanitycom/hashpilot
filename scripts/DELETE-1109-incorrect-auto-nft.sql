-- ========================================
-- 削除: 2025-11-09に誤って付与されたNFTを削除
-- ========================================
--
-- 警告: このスクリプトは取り消せません！
--       必ず事前に INVESTIGATE-1109-auto-nft-bug.sql を実行して、
--       削除対象を確認してください。
--
-- 問題: マイナス$5000の日利設定なのに142個のNFTが誤付与された
-- 原因: V2関数のNFT自動付与が日利の金額を考慮していなかった
--
-- 作成日: 2025-11-19
-- ========================================

-- ========================================
-- ⚠️ 実行前の確認（必ず実行してください）
-- ========================================
-- 1. 11/9に自動付与されたNFT数を確認
SELECT
  '【確認1】11/9に自動付与されたNFT数' as step,
  COUNT(*) as auto_nft_count
FROM nft_master
WHERE acquired_date = '2025-11-09'
  AND nft_type = 'auto';
-- 期待値: 142個（画像では692→834の増加）

-- 2. 削除対象のユーザー一覧を確認
SELECT
  '【確認2】削除対象ユーザー' as step,
  nm.user_id,
  u.email,
  COUNT(nm.id) as nft_count_to_delete,
  ac.cum_usdt,
  ac.auto_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE nm.acquired_date = '2025-11-09'
  AND nm.nft_type = 'auto'
GROUP BY nm.user_id, u.email, ac.cum_usdt, ac.auto_nft_count
ORDER BY nft_count_to_delete DESC;

-- 3. purchases テーブルの削除対象を確認
SELECT
  '【確認3】削除対象のpurchases' as step,
  COUNT(*) as purchase_count
FROM purchases
WHERE purchase_date = '2025-11-09'
  AND nft_type = 'auto'
  AND payment_method = 'cycle_reward';
