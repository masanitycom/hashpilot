-- ========================================
-- 4月の整合性チェックでNGとなった12ユーザーの調査
-- ========================================
-- 目的:
--   check_monthly_integrityのCheck3 (available_usdt整合性)でNGとなった
--   12ユーザーの実態を確認する
--
-- check_monthly_integrityの計算式（CREATE-monthly-integrity-check.sql Check 3より）:
--   expected = SUM(nft_daily_profit) + SUM(monthly_referral_profit) - SUM(completed monthly_withdrawals)
--   actual   = affiliate_cycle.available_usdt
--   diff     = actual - expected
--
-- 計算式の盲点:
--   1. NFT自動購入時の$1100加算が含まれていない（auto_nft_count分）
--   2. NFT買取（buyback）の入金が含まれていない
--   3. 手動補填調整が含まれていない
-- ========================================

-- ========== 12ユーザーの全体像を一気に把握 ==========

WITH target_users AS (
  SELECT user_id FROM (VALUES
    ('07712F'), ('0E9C6C'), ('177B83'), ('1BAA30'),
    ('380CE2'), ('39CD6D'), ('5FAE2C'), ('81F952'),
    ('A6460E'), ('C92A91'), ('CB4F3A'), ('D3E589')
  ) AS t(user_id)
),
profit_sum AS (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE user_id IN (SELECT user_id FROM target_users)
  GROUP BY user_id
),
referral_sum AS (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  WHERE user_id IN (SELECT user_id FROM target_users)
  GROUP BY user_id
),
withdrawn_sum AS (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE user_id IN (SELECT user_id FROM target_users)
    AND status = 'completed'
  GROUP BY user_id
),
nft_count AS (
  SELECT
    user_id,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nft_count,
    COUNT(*) FILTER (WHERE buyback_date IS NULL AND nft_type = 'auto') as active_auto_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NULL AND nft_type = 'manual') as active_manual_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as buyback_count
  FROM nft_master
  WHERE user_id IN (SELECT user_id FROM target_users)
  GROUP BY user_id
)
SELECT
  ac.user_id,
  u.email,
  ac.phase,
  -- AFFILIATE CYCLE
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  ac.auto_nft_count,
  ac.manual_nft_count,
  ac.total_nft_count as cycle_total_nft,
  -- NFT MASTER (実数)
  COALESCE(nc.active_nft_count, 0) as actual_nft,
  COALESCE(nc.active_auto_nft, 0) as actual_auto,
  COALESCE(nc.active_manual_nft, 0) as actual_manual,
  COALESCE(nc.buyback_count, 0) as buyback_count,
  -- 収支計算
  ROUND(COALESCE(ps.total_profit, 0)::numeric, 2) as total_daily_profit,
  ROUND(COALESCE(rs.total_referral, 0)::numeric, 2) as total_referral_profit,
  ROUND(COALESCE(ws.total_withdrawn, 0)::numeric, 2) as total_withdrawn,
  -- expected vs actual
  ROUND((COALESCE(ps.total_profit, 0) + COALESCE(rs.total_referral, 0) - COALESCE(ws.total_withdrawn, 0))::numeric, 2) as expected,
  ROUND(ac.available_usdt::numeric, 2) as actual,
  ROUND((ac.available_usdt - (COALESCE(ps.total_profit, 0) + COALESCE(rs.total_referral, 0) - COALESCE(ws.total_withdrawn, 0)))::numeric, 2) as diff,
  -- $1100加算後の調整版expected (NFT自動購入分を加算)
  ROUND((COALESCE(ps.total_profit, 0) + COALESCE(rs.total_referral, 0) - COALESCE(ws.total_withdrawn, 0) + (ac.auto_nft_count * 1100))::numeric, 2) as expected_with_auto_nft_adjustment,
  ROUND((ac.available_usdt - (COALESCE(ps.total_profit, 0) + COALESCE(rs.total_referral, 0) - COALESCE(ws.total_withdrawn, 0) + (ac.auto_nft_count * 1100)))::numeric, 2) as diff_after_adjustment
FROM affiliate_cycle ac
LEFT JOIN users u ON ac.user_id = u.user_id
LEFT JOIN profit_sum ps ON ac.user_id = ps.user_id
LEFT JOIN referral_sum rs ON ac.user_id = rs.user_id
LEFT JOIN withdrawn_sum ws ON ac.user_id = ws.user_id
LEFT JOIN nft_count nc ON ac.user_id = nc.user_id
WHERE ac.user_id IN (SELECT user_id FROM target_users)
ORDER BY ABS(ac.available_usdt - (COALESCE(ps.total_profit, 0) + COALESCE(rs.total_referral, 0) - COALESCE(ws.total_withdrawn, 0))) DESC;

-- ========== 9A3A16のNFTカウント問題調査 ==========

-- 9A3A16の affiliate_cycle と nft_master の状況
SELECT
  ac.user_id,
  u.email,
  ac.total_nft_count as cycle_total,
  ac.manual_nft_count as cycle_manual,
  ac.auto_nft_count as cycle_auto,
  COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_active,
  COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NOT NULL) as actual_buyback,
  COUNT(nm.id) as actual_total
FROM affiliate_cycle ac
LEFT JOIN users u ON ac.user_id = u.user_id
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
WHERE ac.user_id = '9A3A16'
GROUP BY ac.user_id, u.email, ac.total_nft_count, ac.manual_nft_count, ac.auto_nft_count;

-- 9A3A16のNFT履歴
SELECT
  id,
  nft_sequence,
  nft_type,
  acquired_date,
  buyback_date,
  CASE WHEN buyback_date IS NULL THEN 'ACTIVE' ELSE 'BUYBACK' END as status
FROM nft_master
WHERE user_id = '9A3A16'
ORDER BY nft_sequence;

-- 9A3A16のpurchases履歴（手動購入分）
SELECT
  id,
  nft_quantity,
  amount_usd,
  payment_status,
  admin_approved,
  admin_approved_at,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id = '9A3A16'
ORDER BY created_at;

-- ========== 補助情報: 大きい$1100単位差のユーザーのNFT履歴詳細 ==========

-- 自動NFT購入があったユーザーの履歴（NFTカウント整合性確認用）
SELECT
  nm.user_id,
  COUNT(*) FILTER (WHERE nm.buyback_date IS NULL AND nm.nft_type = 'auto') as auto_active,
  COUNT(*) FILTER (WHERE nm.buyback_date IS NULL AND nm.nft_type = 'manual') as manual_active,
  ac.auto_nft_count as cycle_auto,
  ac.manual_nft_count as cycle_manual,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ac.phase
FROM nft_master nm
JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.user_id IN ('07712F', '177B83', '380CE2', '5FAE2C', '81F952', 'A6460E')
GROUP BY nm.user_id, ac.auto_nft_count, ac.manual_nft_count, ac.cum_usdt, ac.phase
ORDER BY nm.user_id;
