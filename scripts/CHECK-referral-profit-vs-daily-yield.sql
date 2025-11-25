-- ========================================
-- 紹介報酬と日利の整合性確認
-- ========================================
-- 問題: マイナス日利の日に紹介報酬が発生している可能性
-- ========================================

-- 今月（11月）のユーザーJ77883の紹介報酬を日付別に集計
WITH referral_by_date AS (
  SELECT
    date,
    SUM(profit_amount) as total_referral
  FROM user_referral_profit
  WHERE user_id = 'J77883'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30'
  GROUP BY date
),
daily_yield AS (
  SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate
  FROM daily_yield_log
  WHERE date >= '2025-11-01'
    AND date <= '2025-11-30'
)
SELECT
  dy.date,
  dy.yield_rate,
  dy.user_rate,
  CASE
    WHEN dy.yield_rate > 0 THEN 'プラス'
    WHEN dy.yield_rate < 0 THEN 'マイナス'
    ELSE 'ゼロ'
  END as yield_type,
  COALESCE(rb.total_referral, 0) as referral_profit,
  CASE
    WHEN dy.yield_rate < 0 AND COALESCE(rb.total_referral, 0) > 0 THEN '⚠️ 異常'
    WHEN dy.yield_rate > 0 AND COALESCE(rb.total_referral, 0) > 0 THEN '正常'
    WHEN dy.yield_rate < 0 AND COALESCE(rb.total_referral, 0) = 0 THEN '正常'
    ELSE '確認'
  END as status
FROM daily_yield dy
LEFT JOIN referral_by_date rb ON dy.date = rb.date
ORDER BY dy.date DESC;

-- 異常データの件数
SELECT
  COUNT(*) as total_days,
  SUM(CASE WHEN dy.yield_rate < 0 AND COALESCE(rb.total_referral, 0) > 0 THEN 1 ELSE 0 END) as abnormal_days,
  SUM(CASE WHEN dy.yield_rate < 0 AND COALESCE(rb.total_referral, 0) > 0 THEN rb.total_referral ELSE 0 END) as abnormal_amount
FROM daily_yield_log dy
LEFT JOIN (
  SELECT date, SUM(profit_amount) as total_referral
  FROM user_referral_profit
  WHERE user_id = 'J77883'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30'
  GROUP BY date
) rb ON dy.date = rb.date
WHERE dy.date >= '2025-11-01'
  AND dy.date <= '2025-11-30';

-- マイナス日利の日に紹介報酬が発生している詳細
SELECT
  urp.date,
  urp.referral_level,
  urp.child_user_id,
  urp.profit_amount,
  dy.yield_rate,
  dy.user_rate
FROM user_referral_profit urp
JOIN daily_yield_log dy ON urp.date = dy.date
WHERE urp.user_id = 'J77883'
  AND urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
  AND dy.yield_rate < 0
ORDER BY urp.date DESC, urp.referral_level;
