-- ========================================
-- 59C23C, 177B83 の個人利益詳細確認
-- ========================================

-- 1. affiliate_cycleの現在の状態
SELECT '=== affiliate_cycle ===' as section;
SELECT 
  user_id,
  available_usdt,
  cum_usdt,
  withdrawn_referral_usdt,
  phase,
  auto_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id IN ('59C23C', '177B83');

-- 2. 1月の個人利益（日利）合計
SELECT '=== 1月個人利益合計 ===' as section;
SELECT 
  user_id,
  SUM(daily_profit) as 個人利益合計,
  COUNT(*) as レコード数,
  COUNT(DISTINCT date) as 日数
FROM nft_daily_profit
WHERE user_id IN ('59C23C', '177B83')
  AND date >= '2026-01-01' AND date <= '2026-01-31'
GROUP BY user_id;

-- 3. 全期間の個人利益合計
SELECT '=== 全期間個人利益合計 ===' as section;
SELECT 
  user_id,
  SUM(daily_profit) as 全期間個人利益
FROM nft_daily_profit
WHERE user_id IN ('59C23C', '177B83')
GROUP BY user_id;

-- 4. 月別個人利益
SELECT '=== 月別個人利益 ===' as section;
SELECT 
  user_id,
  TO_CHAR(date, 'YYYY-MM') as 年月,
  SUM(daily_profit) as 月間利益,
  COUNT(*) as レコード数
FROM nft_daily_profit
WHERE user_id IN ('59C23C', '177B83')
GROUP BY user_id, TO_CHAR(date, 'YYYY-MM')
ORDER BY user_id, 年月;

-- 5. 出金履歴
SELECT '=== 出金履歴 ===' as section;
SELECT 
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
ORDER BY user_id, withdrawal_month;

-- 6. available_usdtの整合性チェック
-- available_usdt = 全期間個人利益 + 出金済み紹介報酬(NFT自動付与分含む) - 出金済み額
SELECT '=== available_usdt計算 ===' as section;
WITH profit_sum AS (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE user_id IN ('59C23C', '177B83')
  GROUP BY user_id
),
withdrawal_sum AS (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE user_id IN ('59C23C', '177B83')
    AND status = 'completed'
  GROUP BY user_id
)
SELECT 
  ac.user_id,
  ac.available_usdt as 現在のavailable,
  ps.total_profit as 全期間個人利益,
  ac.withdrawn_referral_usdt as 出金済み紹介報酬,
  ac.auto_nft_count * 1100 as NFT自動付与分,
  COALESCE(ws.total_withdrawn, 0) as 出金済み額,
  ps.total_profit + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0) as 計算値
FROM affiliate_cycle ac
LEFT JOIN profit_sum ps ON ac.user_id = ps.user_id
LEFT JOIN withdrawal_sum ws ON ac.user_id = ws.user_id
WHERE ac.user_id IN ('59C23C', '177B83');
