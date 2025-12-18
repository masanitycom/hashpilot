-- ========================================
-- 59C23Cの完全な状況確認
-- ========================================

-- 1. affiliate_cycleの状態
SELECT '【1】affiliate_cycle状態' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 2. 11月の出金履歴
SELECT '【2】11月出金履歴' as section;
SELECT
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C';

-- 3. 11月の日利合計（個人利益）
SELECT '【3】11月の日利合計' as section;
SELECT
  user_id,
  SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE user_id = '59C23C'
  AND date >= '2025-11-01'
  AND date < '2025-12-01'
GROUP BY user_id;

-- 4. 紹介報酬の累計
SELECT '【4】紹介報酬の累計（monthly_referral_profit）' as section;
SELECT
  user_id,
  year_month,
  SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY user_id, year_month
ORDER BY year_month;

-- 5. NFTサイクル計算の確認
SELECT '【5】NFTサイクル計算' as section;
SELECT
  user_id,
  cum_usdt as 紹介報酬累積,
  FLOOR(cum_usdt / 2200) as 自動NFT付与回数,
  MOD(FLOOR(cum_usdt / 1100)::int, 2) as フェーズ計算,
  CASE WHEN MOD(FLOOR(cum_usdt / 1100)::int, 2) = 0 THEN 'USDT' ELSE 'HOLD' END as 計算されたフェーズ,
  phase as 現在のフェーズ,
  cum_usdt - (FLOOR(cum_usdt / 2200) * 2200) as サイクル内残高,
  CASE
    WHEN cum_usdt >= 2200 THEN cum_usdt - 2200 + 1100
    WHEN cum_usdt >= 1100 THEN 0
    ELSE cum_usdt
  END as 出金可能紹介報酬
FROM affiliate_cycle
WHERE user_id = '59C23C';
