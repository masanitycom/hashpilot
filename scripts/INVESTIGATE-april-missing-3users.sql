-- ========================================
-- 4月の月末出金リストから漏れた3名の調査
-- 59C23C, 2F6364, CA7902
-- ========================================

-- 1. ユーザー基本情報
SELECT
  u.user_id,
  u.email,
  u.is_active_investor,
  u.has_approved_nft,
  u.is_pegasus_exchange,
  u.operation_start_date,
  u.total_purchases,
  u.created_at
FROM users u
WHERE u.user_id IN ('59C23C', '2F6364', 'CA7902')
ORDER BY u.user_id;

-- 2. affiliate_cycle 状態
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  ac.phase,
  ac.auto_nft_count,
  ac.manual_nft_count,
  ac.total_nft_count,
  ac.last_updated
FROM affiliate_cycle ac
WHERE ac.user_id IN ('59C23C', '2F6364', 'CA7902')
ORDER BY ac.user_id;

-- 3. nft_master状態（アクティブNFT・買取状況）
SELECT
  user_id,
  COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nfts,
  COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as buyback_nfts,
  COUNT(*) FILTER (WHERE buyback_date IS NULL AND operation_start_date <= '2026-04-30') as active_apr30,
  MIN(operation_start_date) as earliest_op_start,
  MAX(buyback_date) as latest_buyback
FROM nft_master
WHERE user_id IN ('59C23C', '2F6364', 'CA7902')
GROUP BY user_id
ORDER BY user_id;

-- 4. monthly_withdrawals の全履歴
SELECT
  user_id,
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(referral_amount::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total,
  task_completed,
  notes,
  created_at,
  updated_at
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '2F6364', 'CA7902')
ORDER BY user_id, withdrawal_month;

-- 5. 4月の日利
SELECT
  user_id,
  COUNT(*) as profit_records,
  COUNT(DISTINCT date) as profit_days,
  ROUND(SUM(daily_profit)::numeric, 2) as total_april_profit,
  MIN(date) as first_date,
  MAX(date) as last_date
FROM nft_daily_profit
WHERE user_id IN ('59C23C', '2F6364', 'CA7902')
  AND date >= '2026-04-01'
  AND date < '2026-05-01'
GROUP BY user_id
ORDER BY user_id;

-- 6. 4月の紹介報酬
SELECT
  user_id,
  year_month,
  ROUND(SUM(profit_amount)::numeric, 2) as monthly_referral
FROM monthly_referral_profit
WHERE user_id IN ('59C23C', '2F6364', 'CA7902')
  AND year_month = '2026-04'
GROUP BY user_id, year_month
ORDER BY user_id;

-- 7. 買取申請履歴
SELECT
  user_id,
  status,
  total_nft_count,
  manual_nft_count,
  auto_nft_count,
  total_buyback_amount,
  request_date,
  processed_at
FROM buyback_requests
WHERE user_id IN ('59C23C', '2F6364', 'CA7902')
ORDER BY user_id, processed_at DESC;
