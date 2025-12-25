-- ========================================
-- 3ユーザーの12月補填コスト計算（続き）
-- ========================================

-- 1. 12月の1NFTあたり利益合計（個人利益）
SELECT
  COUNT(*) as december_days,
  SUM(profit_per_nft) as total_profit_per_nft_sum,
  SUM(profit_per_nft) * 3 as personal_profit_3users
FROM daily_yield_log_v2
WHERE date >= '2025-12-01';

-- 2. 3ユーザーの紹介者（この3名の紹介者に紹介報酬を払う必要がある）
SELECT
  u.user_id,
  u.email,
  u.referrer_user_id as level1_referrer,
  r1.email as level1_email,
  r1.referrer_user_id as level2_referrer,
  r2.email as level2_email,
  r2.referrer_user_id as level3_referrer,
  r3.email as level3_email
FROM users u
LEFT JOIN users r1 ON u.referrer_user_id = r1.user_id
LEFT JOIN users r2 ON r1.referrer_user_id = r2.user_id
LEFT JOIN users r3 ON r2.referrer_user_id = r3.user_id
WHERE u.user_id IN ('225F87', '20248A', '5A708D');

-- 3. 3ユーザーの下にいる紹介者（3名が紹介報酬を受け取る側）
SELECT
  '=== 3ユーザーが紹介している人（Level 1） ===' as info;
  
SELECT
  referrer.user_id as referrer_id,
  referrer.email as referrer_email,
  referred.user_id as referred_id,
  referred.email as referred_email,
  referred.has_approved_nft,
  referred.operation_start_date
FROM users referred
JOIN users referrer ON referred.referrer_user_id = referrer.user_id
WHERE referrer.user_id IN ('225F87', '20248A', '5A708D')
  AND referred.has_approved_nft = true;

-- 4. 紹介報酬計算のための日利合計
-- 3ユーザーの紹介者への報酬 = 3ユーザーの日利 × 20%/10%/5%
SELECT
  '=== 補填コスト計算 ===' as info;

WITH december_profit AS (
  SELECT SUM(profit_per_nft) as total_per_nft
  FROM daily_yield_log_v2
  WHERE date >= '2025-12-01'
)
SELECT
  dp.total_per_nft as "1NFTあたり12月合計",
  dp.total_per_nft * 3 as "3ユーザー個人利益合計",
  dp.total_per_nft * 3 * 0.20 as "Level1紹介報酬(20%)",
  dp.total_per_nft * 3 * 0.10 as "Level2紹介報酬(10%)",
  dp.total_per_nft * 3 * 0.05 as "Level3紹介報酬(5%)",
  dp.total_per_nft * 3 * (1 + 0.20 + 0.10 + 0.05) as "合計会社負担(最大)"
FROM december_profit dp;
