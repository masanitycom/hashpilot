-- ========================================
-- A81A5Eの12月$14.73の出所を調査
-- ========================================

-- ========================================
-- 1. monthly_withdrawals の詳細
-- ========================================
SELECT '=== monthly_withdrawals 詳細 ===' as section;

SELECT
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status,
  created_at,
  updated_at
FROM monthly_withdrawals
WHERE user_id = 'A81A5E'
ORDER BY withdrawal_month;

-- ========================================
-- 2. nft_daily_profit 全履歴
-- ========================================
SELECT '=== nft_daily_profit 全履歴 ===' as section;

SELECT
  user_id,
  date,
  daily_profit,
  created_at
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
ORDER BY date;

-- ========================================
-- 3. user_daily_profit（旧テーブル）があれば確認
-- ========================================
SELECT '=== user_daily_profit（旧テーブル）===' as section;

SELECT
  user_id,
  date,
  daily_profit
FROM user_daily_profit
WHERE user_id = 'A81A5E'
ORDER BY date;

-- ========================================
-- 4. affiliate_cycle の履歴
-- ========================================
SELECT '=== affiliate_cycle 詳細 ===' as section;

SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  auto_nft_count,
  manual_nft_count,
  updated_at
FROM affiliate_cycle
WHERE user_id = 'A81A5E';

-- ========================================
-- 5. 12月の計算元データを探る
-- monthly_withdrawalsのpersonal_amountはどうやって計算された？
-- ========================================
SELECT '=== 12月出金処理時点での計算 ===' as section;

-- 12月出金は11月分の日利を反映するはず
-- nft_daily_profit で11月のデータがあるか？
SELECT
  user_id,
  SUM(daily_profit) as november_total
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
  AND date >= '2025-11-01' AND date <= '2025-11-30'
GROUP BY user_id;

-- ========================================
-- 6. operation_start_date の変更履歴
-- ========================================
SELECT '=== users テーブル詳細 ===' as section;

SELECT
  user_id,
  email,
  operation_start_date,
  is_pegasus_exchange,
  has_approved_nft,
  created_at,
  updated_at
FROM users
WHERE user_id = 'A81A5E';

