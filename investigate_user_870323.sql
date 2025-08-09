-- ユーザー870323のデータ不整合調査 --

-- ========================================================
-- 1. purchasesテーブルで870323の全購入履歴を調査
-- ========================================================
SELECT 
  p.id,
  p.user_id,
  p.nft_quantity,
  p.amount_usd,
  p.payment_status,
  p.nft_sent,
  p.admin_approved,
  p.created_at,
  p.confirmed_at,
  p.completed_at,
  p.updated_at,
  -- 削除済みレコードも含めて確認するためのメタ情報
  CASE WHEN p.deleted_at IS NULL THEN 'アクティブ' ELSE 'ソフト削除済み' END as record_status
FROM purchases p
WHERE p.user_id = '870323'
ORDER BY p.created_at DESC;

-- ========================================================
-- 2. usersテーブルの870323の詳細情報
-- ========================================================
SELECT 
  u.id,
  u.user_id,
  u.email,
  u.full_name,
  u.referrer_user_id,
  u.total_purchases,
  u.total_referral_earnings,
  u.is_active,
  u.created_at,
  u.updated_at
FROM users u
WHERE u.user_id = '870323';

-- ========================================================
-- 3. affiliate_cycleテーブルの870323の詳細情報
-- ========================================================
SELECT 
  ac.id,
  ac.user_id,
  ac.cycle_start_date,
  ac.cycle_end_date,
  ac.total_nft_count,
  ac.manual_nft_count,
  ac.auto_purchased_nft_count,
  ac.previous_cycle_nft_count,
  ac.total_profit,
  ac.operation_start_date,
  ac.is_active,
  ac.created_at,
  ac.updated_at
FROM affiliate_cycle ac
WHERE ac.user_id = '870323'
ORDER BY ac.cycle_start_date DESC;

-- ========================================================
-- 4. user_daily_profitsテーブルで870323の利益履歴を確認
-- ========================================================
SELECT 
  udp.id,
  udp.user_id,
  udp.profit_date,
  udp.daily_profit_usd,
  udp.nft_count_at_calculation,
  udp.created_at
FROM user_daily_profits udp
WHERE udp.user_id = '870323'
ORDER BY udp.profit_date DESC
LIMIT 10;

-- ========================================================
-- 5. 購入金額の集計確認
-- ========================================================
SELECT 
  COUNT(*) as total_purchases,
  SUM(amount_usd) as total_amount,
  SUM(nft_quantity) as total_nft_quantity,
  COUNT(CASE WHEN payment_status = 'approved' AND admin_approved = true THEN 1 END) as approved_purchases,
  SUM(CASE WHEN payment_status = 'approved' AND admin_approved = true THEN amount_usd ELSE 0 END) as approved_amount,
  SUM(CASE WHEN payment_status = 'approved' AND admin_approved = true THEN nft_quantity ELSE 0 END) as approved_nft_quantity
FROM purchases 
WHERE user_id = '870323';

-- ========================================================
-- 6. 購入ステータス別の詳細分析
-- ========================================================
SELECT 
  payment_status,
  admin_approved,
  nft_sent,
  COUNT(*) as count,
  SUM(amount_usd) as total_amount,
  SUM(nft_quantity) as total_nft,
  MIN(created_at) as earliest_purchase,
  MAX(created_at) as latest_purchase
FROM purchases 
WHERE user_id = '870323'
GROUP BY payment_status, admin_approved, nft_sent
ORDER BY count DESC;

-- ========================================================
-- 7. 削除済みレコードの確認（deleted_atカラムが存在する場合）
-- ========================================================
-- Note: deleted_atカラムが存在しない場合はエラーになる可能性があります
SELECT 
  p.id,
  p.user_id,
  p.amount_usd,
  p.nft_quantity,
  p.payment_status,
  p.admin_approved,
  p.created_at,
  p.deleted_at
FROM purchases p
WHERE p.user_id = '870323' 
  AND p.deleted_at IS NOT NULL;

-- ========================================================
-- 8. NFT数の不整合調査 - affiliate_cycleの計算根拠確認
-- ========================================================
-- manual_nft_countとtotal_nft_countの関係を確認
SELECT 
  'affiliate_cycle' as source,
  total_nft_count,
  manual_nft_count,
  auto_purchased_nft_count,
  previous_cycle_nft_count,
  (manual_nft_count + auto_purchased_nft_count + previous_cycle_nft_count) as calculated_total
FROM affiliate_cycle 
WHERE user_id = '870323';

-- ========================================================
-- 9. 重複や異常なレコードの確認
-- ========================================================
-- 同じ金額・同じ日時の重複購入がないか確認
SELECT 
  amount_usd,
  nft_quantity,
  DATE(created_at) as purchase_date,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::text, ', ') as purchase_ids
FROM purchases 
WHERE user_id = '870323'
GROUP BY amount_usd, nft_quantity, DATE(created_at)
HAVING COUNT(*) > 1;

-- ========================================================
-- 10. 他のユーザーとの比較分析（参考用）
-- ========================================================
-- 類似の購入金額を持つ他のユーザーの状況
SELECT 
  u.user_id,
  u.total_purchases,
  COUNT(p.id) as actual_purchase_count,
  SUM(p.amount_usd) as actual_purchase_sum,
  ac.total_nft_count
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.payment_status = 'approved' AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.total_purchases BETWEEN 2000 AND 2500
GROUP BY u.user_id, u.total_purchases, ac.total_nft_count
ORDER BY u.total_purchases DESC
LIMIT 5;

-- ========================================================
-- 最終確認: データの整合性チェック
-- ========================================================
SELECT 
  '870323' as investigated_user,
  (SELECT total_purchases FROM users WHERE user_id = '870323') as users_total_purchases,
  (SELECT SUM(amount_usd) FROM purchases WHERE user_id = '870323' AND payment_status = 'approved' AND admin_approved = true) as actual_approved_purchases,
  (SELECT total_nft_count FROM affiliate_cycle WHERE user_id = '870323') as affiliate_cycle_nft_count,
  (SELECT manual_nft_count FROM affiliate_cycle WHERE user_id = '870323') as affiliate_cycle_manual_nft,
  (SELECT SUM(nft_quantity) FROM purchases WHERE user_id = '870323' AND payment_status = 'approved' AND admin_approved = true) as actual_approved_nft_quantity;