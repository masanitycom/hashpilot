-- ========================================
-- 日利二重加算の検証
-- ========================================
-- 仮説: available_usdtに日利が2回加算された
-- ========================================

-- 1. 1NFTユーザーの過剰額 vs 12月日利
SELECT '=== 1. 1NFT保有・12/1開始ユーザーの検証 ===' as section;
SELECT
  ndp.user_id,
  nm.nft_count,
  SUM(ndp.daily_profit) as dec_profit,
  23.912 as typical_over_amount,
  ROUND(23.912 / SUM(ndp.daily_profit), 2) as ratio
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) as nft_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm ON ndp.user_id = nm.user_id
WHERE u.operation_start_date = '2025-12-01'
  AND nm.nft_count = 1
GROUP BY ndp.user_id, nm.nft_count
LIMIT 5;

-- 2. 複数NFTユーザーでも同じ比率か確認
SELECT '=== 2. NFT数別の過剰額比率 ===' as section;
WITH user_profits AS (
  SELECT
    ndp.user_id,
    nm.nft_count,
    SUM(ndp.daily_profit) as dec_profit
  FROM nft_daily_profit ndp
  JOIN users u ON ndp.user_id = u.user_id
  LEFT JOIN (
    SELECT user_id, COUNT(*) as nft_count
    FROM nft_master
    WHERE buyback_date IS NULL
    GROUP BY user_id
  ) nm ON ndp.user_id = nm.user_id
  WHERE u.operation_start_date = '2025-12-01'
  GROUP BY ndp.user_id, nm.nft_count
)
SELECT
  nft_count,
  COUNT(*) as user_count,
  ROUND(AVG(dec_profit), 2) as avg_profit,
  ROUND(23.912 * nft_count, 2) as expected_over_amount
FROM user_profits
WHERE nft_count IS NOT NULL
GROUP BY nft_count
ORDER BY nft_count;

-- 3. process_monthly_withdrawals関数を確認
-- この関数がavailable_usdtを二重に加算している可能性
SELECT '=== 3. 月末出金処理の確認 ===' as section;
SELECT
  user_id,
  withdrawal_month,
  total_amount,
  created_at
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
ORDER BY created_at
LIMIT 10;

-- 4. 過剰額のパターン分析（NFT数との相関）
SELECT '=== 4. 過剰額 ÷ NFT数 = 定数？ ===' as section;
WITH over_amounts AS (
  SELECT
    ac.user_id,
    nm.nft_count,
    ac.available_usdt - (COALESCE(dp.total, 0) + COALESCE(rp.total, 0)) as over_amount
  FROM affiliate_cycle ac
  JOIN users u ON ac.user_id = u.user_id
  LEFT JOIN (
    SELECT user_id, COUNT(*) as nft_count
    FROM nft_master
    WHERE buyback_date IS NULL
    GROUP BY user_id
  ) nm ON ac.user_id = nm.user_id
  LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as total
    FROM nft_daily_profit
    GROUP BY user_id
  ) dp ON ac.user_id = dp.user_id
  LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as total
    FROM user_referral_profit_monthly
    GROUP BY user_id
  ) rp ON ac.user_id = rp.user_id
  WHERE u.operation_start_date = '2025-12-01'
)
SELECT
  user_id,
  nft_count,
  ROUND(over_amount, 2) as over_amount,
  ROUND(over_amount / NULLIF(nft_count, 0), 2) as over_per_nft
FROM over_amounts
WHERE over_amount > 1
ORDER BY nft_count, over_amount DESC;
