-- 12/15運用開始ユーザーの日利配布状況を確認
-- 実行日: 2025-12-17

-- ========================================
-- STEP 1: 12/15運用開始のユーザー一覧
-- ========================================
SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  u.is_pegasus_exchange,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count
FROM users u
WHERE u.operation_start_date = '2025-12-15'
ORDER BY u.user_id;

-- ========================================
-- STEP 2: 12/15-16の日利配布対象NFT数を確認
-- ========================================
SELECT
  '2025-12-15' as check_date,
  COUNT(*) as nft_count
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-12-15'

UNION ALL

SELECT
  '2025-12-16' as check_date,
  COUNT(*) as nft_count
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-12-16';

-- ========================================
-- STEP 3: 12/15運用開始ユーザーの日利記録を確認
-- ========================================
SELECT
  u.user_id,
  u.operation_start_date,
  udp.date,
  udp.daily_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
  AND udp.date IN ('2025-12-15', '2025-12-16')
WHERE u.operation_start_date = '2025-12-15'
ORDER BY u.user_id, udp.date;

-- ========================================
-- STEP 4: 12/15運用開始ユーザーのaffiliate_cycle確認
-- ========================================
SELECT
  u.user_id,
  u.operation_start_date,
  ac.available_usdt,
  ac.cum_usdt,
  ac.phase
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-12-15'
ORDER BY u.user_id;

-- ========================================
-- STEP 5: daily_yield_log_v2の12/15, 12/16記録を確認
-- ========================================
SELECT
  date,
  daily_pnl,
  total_nft_count,
  profit_per_nft,
  distribution_dividend
FROM daily_yield_log_v2
WHERE date IN ('2025-12-15', '2025-12-16')
ORDER BY date;

-- ========================================
-- STEP 6: 問題のあるユーザーを特定
-- 12/15運用開始だがhas_approved_nft=falseまたはoperation_start_date=NULL
-- ========================================
SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count,
  (SELECT COUNT(*) FROM purchases p WHERE p.user_id = u.user_id AND p.admin_approved = true) as approved_purchases
FROM users u
WHERE u.operation_start_date = '2025-12-15'
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL);

-- ========================================
-- STEP 7: 12/15-16に日利を受け取ったユーザー数と受け取っていないユーザー数
-- ========================================
SELECT
  'received_profit' as status,
  COUNT(DISTINCT user_id) as user_count
FROM user_daily_profit
WHERE date IN ('2025-12-15', '2025-12-16')
  AND user_id IN (SELECT user_id FROM users WHERE operation_start_date = '2025-12-15')

UNION ALL

SELECT
  'no_profit' as status,
  COUNT(*) as user_count
FROM users u
WHERE u.operation_start_date = '2025-12-15'
  AND NOT EXISTS (
    SELECT 1 FROM user_daily_profit udp
    WHERE udp.user_id = u.user_id
      AND udp.date IN ('2025-12-15', '2025-12-16')
  );

-- ========================================
-- STEP 8: 本番環境で現在使われているRPC関数の定義を確認
-- ========================================
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';
