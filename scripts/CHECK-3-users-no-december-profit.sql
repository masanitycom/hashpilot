-- ========================================
-- 12月運用されていない3ユーザーの調査
-- balance.p.p.p.p.1060@gmail.com
-- akihiro.y.grant@gmail.com
-- feel.me.yurie@gmail.com
-- ========================================

-- 1. 基本情報
SELECT
  '=== 基本情報 ===' as section;

SELECT
  user_id,
  email,
  full_name,
  total_purchases,
  has_approved_nft,
  is_active_investor,
  operation_start_date,
  is_pegasus_exchange,
  created_at
FROM users
WHERE email IN (
  'balance.p.p.p.p.1060@gmail.com',
  'akihiro.y.grant@gmail.com',
  'feel.me.yurie@gmail.com'
)
ORDER BY email;

-- 2. NFT保有状況
SELECT
  '=== NFT保有状況 ===' as section;

SELECT
  nm.user_id,
  u.email,
  nm.id as nft_id,
  nm.nft_type,
  nm.acquired_date,
  nm.buyback_date,
  nm.created_at
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE u.email IN (
  'balance.p.p.p.p.1060@gmail.com',
  'akihiro.y.grant@gmail.com',
  'feel.me.yurie@gmail.com'
)
ORDER BY u.email, nm.acquired_date;

-- 3. 購入履歴
SELECT
  '=== 購入履歴 ===' as section;

SELECT
  p.user_id,
  u.email,
  p.amount_usd,
  p.nft_quantity,
  p.admin_approved,
  p.admin_approved_at,
  p.created_at
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE u.email IN (
  'balance.p.p.p.p.1060@gmail.com',
  'akihiro.y.grant@gmail.com',
  'feel.me.yurie@gmail.com'
)
ORDER BY u.email, p.created_at;

-- 4. 12月の日利配布状況
SELECT
  '=== 12月の日利配布状況 ===' as section;

SELECT
  ndp.user_id,
  u.email,
  ndp.profit_date,
  ndp.nft_count,
  ndp.total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.email IN (
  'balance.p.p.p.p.1060@gmail.com',
  'akihiro.y.grant@gmail.com',
  'feel.me.yurie@gmail.com'
)
AND ndp.profit_date >= '2025-12-01'
ORDER BY u.email, ndp.profit_date;

-- 5. affiliate_cycle状況
SELECT
  '=== affiliate_cycle状況 ===' as section;

SELECT
  ac.user_id,
  u.email,
  ac.manual_nft_count,
  ac.auto_nft_count,
  ac.total_nft_count,
  ac.cum_usdt,
  ac.available_usdt,
  ac.phase
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.email IN (
  'balance.p.p.p.p.1060@gmail.com',
  'akihiro.y.grant@gmail.com',
  'feel.me.yurie@gmail.com'
)
ORDER BY u.email;

-- 6. 日利配布の対象条件チェック
SELECT
  '=== 日利配布対象条件チェック ===' as section;

SELECT
  user_id,
  email,
  has_approved_nft,
  operation_start_date,
  is_pegasus_exchange,
  CASE
    WHEN has_approved_nft = false THEN '❌ has_approved_nft = false'
    WHEN operation_start_date IS NULL THEN '❌ operation_start_date = NULL'
    WHEN operation_start_date > CURRENT_DATE THEN '❌ operation_start_date > 今日 (' || operation_start_date || ')'
    WHEN is_pegasus_exchange = true THEN '⚠️ ペガサス交換ユーザー'
    ELSE '✅ 対象'
  END as status
FROM users
WHERE email IN (
  'balance.p.p.p.p.1060@gmail.com',
  'akihiro.y.grant@gmail.com',
  'feel.me.yurie@gmail.com'
)
ORDER BY email;
