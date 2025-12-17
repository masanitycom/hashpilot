-- NFTサイクルと紹介報酬の不一致を調査
-- ユーザー7A9637を例に確認

-- 1. affiliate_cycleのcum_usdt（NFTサイクルカードで使用）
SELECT
  'affiliate_cycle' as source,
  user_id,
  cum_usdt,
  available_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 2. monthly_referral_profitの合計（紹介報酬カードで使用）
SELECT
  'monthly_referral_profit' as source,
  user_id,
  year_month,
  referral_level,
  profit_amount
FROM monthly_referral_profit
WHERE user_id = '7A9637'
ORDER BY year_month DESC, referral_level;

-- 3. 紹介報酬の合計
SELECT
  'total_referral_profit' as source,
  user_id,
  SUM(profit_amount) as total
FROM monthly_referral_profit
WHERE user_id = '7A9637'
GROUP BY user_id;

-- 4. user_referral_profitの合計（日次紹介報酬）
SELECT
  'user_referral_profit_total' as source,
  user_id,
  SUM(profit_amount) as total
FROM user_referral_profit
WHERE user_id = '7A9637'
GROUP BY user_id;

-- 5. 全ユーザーでcum_usdtと紹介報酬合計の比較
SELECT
  ac.user_id,
  ac.cum_usdt as cycle_cum_usdt,
  COALESCE(rp.total_referral, 0) as referral_profit_total,
  ac.cum_usdt - COALESCE(rp.total_referral, 0) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ac.cum_usdt > 0
ORDER BY ABS(ac.cum_usdt - COALESCE(rp.total_referral, 0)) DESC
LIMIT 20;
