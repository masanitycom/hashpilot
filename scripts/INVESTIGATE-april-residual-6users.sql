-- ========================================
-- 4月整合性チェック残余6名の詳細調査
-- ========================================
-- 残った6名:
--   177B83 (+$652.67): カテゴリB単独
--   0E9C6C, 39CD6D, D3E589, CB4F3A, C92A91 (+$20〜67): カテゴリC（補填組）
-- ========================================

-- ========== Cカテゴリ5名の月別収支調査 ==========
-- 補填の痕跡を探す（2025年12月〜2026年2月の補填期間に着目）

-- 5-1. 月別 nft_daily_profit
SELECT
  user_id,
  DATE_TRUNC('month', date)::DATE as month,
  COUNT(*) as days,
  ROUND(SUM(daily_profit)::numeric, 2) as monthly_profit
FROM nft_daily_profit
WHERE user_id IN ('0E9C6C', '39CD6D', 'D3E589', 'CB4F3A', 'C92A91', '177B83')
GROUP BY user_id, DATE_TRUNC('month', date)
ORDER BY user_id, month;

-- 5-2. 月別 monthly_referral_profit
SELECT
  user_id,
  year_month,
  ROUND(SUM(profit_amount)::numeric, 2) as monthly_referral
FROM monthly_referral_profit
WHERE user_id IN ('0E9C6C', '39CD6D', 'D3E589', 'CB4F3A', 'C92A91', '177B83')
GROUP BY user_id, year_month
ORDER BY user_id, year_month;

-- 5-3. monthly_withdrawals 全件
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
WHERE user_id IN ('0E9C6C', '39CD6D', 'D3E589', 'CB4F3A', 'C92A91', '177B83')
ORDER BY user_id, withdrawal_month;

-- 5-4. affiliate_cycle の現在状態
SELECT
  ac.user_id,
  u.email,
  ROUND(ac.available_usdt::numeric, 2) as available,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_ref,
  ac.phase,
  ac.auto_nft_count,
  ac.manual_nft_count,
  ac.last_updated,
  ac.updated_at
FROM affiliate_cycle ac
LEFT JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id IN ('0E9C6C', '39CD6D', 'D3E589', 'CB4F3A', 'C92A91', '177B83')
ORDER BY ac.user_id;

-- ========== 補填痕跡: 12月〜2月の特定日に大きな日利が補填されたか ==========

-- 1日あたりの異常な額（$30以上）の日利を抽出（補填の可能性）
SELECT
  user_id,
  date,
  ROUND(daily_profit::numeric, 2) as daily_profit,
  daily_yield_rate,
  user_rate
FROM nft_daily_profit
WHERE user_id IN ('0E9C6C', '39CD6D', 'D3E589', 'CB4F3A', 'C92A91', '177B83')
  AND ABS(daily_profit) >= 30
ORDER BY user_id, date;

-- ========== 過去の補填スクリプトの痕跡確認 ==========
-- 補填組5名(0E9C6C, 39CD6D, D3E589, CB4F3A, C92A91)が2026-03-04に修正されているはず
-- nft_daily_profit のうち2025-12〜2026-02期間で created_at が 2026-03 のものを抽出

SELECT
  user_id,
  date as profit_date,
  ROUND(daily_profit::numeric, 2) as daily_profit,
  created_at,
  CASE
    WHEN created_at::DATE >= '2026-03-01' THEN 'BACKFILL (2026-03以降に作成)'
    ELSE 'NORMAL'
  END as creation_type
FROM nft_daily_profit
WHERE user_id IN ('0E9C6C', '39CD6D', 'D3E589', 'CB4F3A', 'C92A91')
ORDER BY user_id, date;

-- ========== 177B83の特別調査 ==========
-- $652.67の余剰の原因を探す

-- 177B83の全 nft_daily_profit
SELECT
  date,
  ROUND(daily_profit::numeric, 2) as daily_profit,
  ROUND(base_amount::numeric, 2) as base_amount,
  daily_yield_rate,
  user_rate,
  created_at
FROM nft_daily_profit
WHERE user_id = '177B83'
ORDER BY date;

-- 177B83の購入履歴
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
WHERE user_id = '177B83'
ORDER BY created_at;

-- 177B83のNFT履歴
SELECT
  nft_sequence,
  nft_type,
  acquired_date,
  buyback_date,
  CASE WHEN buyback_date IS NULL THEN 'ACTIVE' ELSE 'BUYBACK' END as status
FROM nft_master
WHERE user_id = '177B83'
ORDER BY nft_sequence;

-- 177B83のbuyback_requests（買取申請があれば）
SELECT *
FROM buyback_requests
WHERE user_id = '177B83'
ORDER BY created_at;
