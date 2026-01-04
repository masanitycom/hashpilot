-- ========================================
-- HOLDフェーズユーザーの出金合計確認
-- ========================================

-- 問題: HOLDユーザーは払出可能な紹介報酬のみ出金可能なのに、
-- 全額が出金合計に含まれている

-- 1. HOLDフェーズユーザーの12月出金データ
SELECT '=== HOLDフェーズユーザーの12月出金 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.cum_usdt,
  ac.available_usdt,

  -- 11月紹介報酬（12月出金で払うべき）
  COALESCE(nov.nov_referral, 0) as nov_referral,

  -- 12月出金データ
  mw.personal_amount,
  mw.referral_amount as stored_referral,
  mw.total_amount as current_total,

  -- HOLDの場合の計算
  -- 払出可能 = 11月紹介報酬 - (cum_usdt - available_usdt - 1100を超えた分)
  -- 簡易計算: phase=HOLDの場合、cum_usdt < 2200 なら払出可 = cum_usdt - 1100
  CASE
    WHEN ac.phase = 'HOLD' AND ac.cum_usdt >= 1100 AND ac.cum_usdt < 2200 THEN
      GREATEST(0, ac.cum_usdt - 1100)
    ELSE
      COALESCE(nov.nov_referral, 0)
  END as withdrawable_referral,

  -- 正しい出金合計
  mw.personal_amount +
  CASE
    WHEN ac.phase = 'HOLD' AND ac.cum_usdt >= 1100 AND ac.cum_usdt < 2200 THEN
      GREATEST(0, ac.cum_usdt - 1100)
    ELSE
      COALESCE(nov.nov_referral, 0)
  END as correct_total

FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) nov ON mw.user_id = nov.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'HOLD'
ORDER BY mw.total_amount DESC;

-- 2. 177B83の詳細確認
SELECT '=== 177B83の詳細 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.cum_usdt,
  ac.available_usdt,
  ac.withdrawn_referral_usdt,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  -- 11月紹介報酬
  (SELECT SUM(profit_amount) FROM monthly_referral_profit WHERE user_id = mw.user_id AND year_month = '2025-11') as nov_referral,
  -- 12月紹介報酬
  (SELECT SUM(profit_amount) FROM monthly_referral_profit WHERE user_id = mw.user_id AND year_month = '2025-12') as dec_referral
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id = '177B83'
  AND mw.withdrawal_month = '2025-12-01';

-- 3. 59C23Cの詳細確認
SELECT '=== 59C23Cの詳細 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.cum_usdt,
  ac.available_usdt,
  ac.withdrawn_referral_usdt,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  -- 11月紹介報酬
  (SELECT SUM(profit_amount) FROM monthly_referral_profit WHERE user_id = mw.user_id AND year_month = '2025-11') as nov_referral,
  -- 12月紹介報酬
  (SELECT SUM(profit_amount) FROM monthly_referral_profit WHERE user_id = mw.user_id AND year_month = '2025-12') as dec_referral
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id = '59C23C'
  AND mw.withdrawal_month = '2025-12-01';
