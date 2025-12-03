-- ========================================
-- cum_usdtをmonthly_referral_profitの合計と同期
-- 日次紹介報酬は廃止、月次のみ使用
-- ========================================

-- 1. 現状の不整合を確認
SELECT
  ac.user_id,
  ac.cum_usdt as current_cum_usdt,
  COALESCE(mrp.total_referral, 0) as monthly_referral_total,
  ac.cum_usdt - COALESCE(mrp.total_referral, 0) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.cum_usdt > 0 OR COALESCE(mrp.total_referral, 0) > 0
ORDER BY ABS(ac.cum_usdt - COALESCE(mrp.total_referral, 0)) DESC
LIMIT 20;

-- 2. cum_usdtをmonthly_referral_profitの合計で更新
UPDATE affiliate_cycle ac
SET cum_usdt = COALESCE(mrp.total_referral, 0)
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id;

-- 3. 紹介報酬がないユーザーはcum_usdtを0に
UPDATE affiliate_cycle ac
SET cum_usdt = 0
WHERE NOT EXISTS (
  SELECT 1 FROM monthly_referral_profit mrp WHERE mrp.user_id = ac.user_id
)
AND ac.cum_usdt > 0;

-- 4. phaseを再計算
-- 0〜1099: USDT, 1100〜2199: HOLD, 2200〜3299: USDT, ...
UPDATE affiliate_cycle
SET phase = CASE
  WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
  ELSE 'HOLD'
END
WHERE cum_usdt >= 0;

-- 5. 更新後の確認
SELECT
  ac.user_id,
  ac.cum_usdt as new_cum_usdt,
  ac.phase,
  COALESCE(mrp.total_referral, 0) as monthly_referral_total
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
ORDER BY ac.cum_usdt DESC
LIMIT 20;
