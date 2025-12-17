-- ========================================
-- cum_usdtをuser_referral_profitの合計と同期
-- ========================================

-- 1. 現状の不整合を確認
SELECT
  ac.user_id,
  ac.cum_usdt as current_cum_usdt,
  COALESCE(rp.total_referral, 0) as actual_referral_total,
  ac.cum_usdt - COALESCE(rp.total_referral, 0) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ac.cum_usdt > 0
ORDER BY ABS(ac.cum_usdt - COALESCE(rp.total_referral, 0)) DESC
LIMIT 10;

-- 2. cum_usdtをuser_referral_profitの合計で更新
-- ※ 実行前に確認してください
UPDATE affiliate_cycle ac
SET cum_usdt = COALESCE(rp.total_referral, 0)
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit
  GROUP BY user_id
) rp
WHERE ac.user_id = rp.user_id;

-- 3. 紹介報酬がないユーザーはcum_usdtを0に
UPDATE affiliate_cycle ac
SET cum_usdt = 0
WHERE NOT EXISTS (
  SELECT 1 FROM user_referral_profit rp WHERE rp.user_id = ac.user_id
)
AND ac.cum_usdt > 0;

-- 4. phaseを再計算（cum_usdt % 1100で判定）
UPDATE affiliate_cycle
SET phase = CASE
  WHEN cum_usdt < 1100 THEN 'USDT'
  WHEN (cum_usdt::numeric % 2200) < 1100 THEN 'USDT'
  ELSE 'HOLD'
END;

-- 5. 更新後の確認
SELECT
  ac.user_id,
  ac.cum_usdt as new_cum_usdt,
  COALESCE(rp.total_referral, 0) as referral_total,
  ac.phase
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ac.cum_usdt > 0
ORDER BY ac.cum_usdt DESC
LIMIT 20;
