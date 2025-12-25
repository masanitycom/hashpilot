-- ========================================
-- 3ユーザーの12月補填コスト計算
-- 個人利益 + 紹介報酬
-- ========================================

-- 1. 12月の日利設定状況を確認（daily_yield_log_v2のカラム確認）
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'daily_yield_log_v2'
ORDER BY ordinal_position;

-- 2. 12月の日利データ
SELECT *
FROM daily_yield_log_v2
WHERE created_at >= '2025-12-01'
ORDER BY created_at DESC
LIMIT 30;

-- 3. 12月の各日の1NFTあたり利益を取得
SELECT
  DATE(created_at) as yield_date,
  profit_per_nft,
  total_pnl
FROM daily_yield_log_v2
WHERE created_at >= '2025-12-01'
ORDER BY created_at;

-- 4. 3ユーザー（3NFT）の12月個人利益合計
-- profit_per_nft × 3NFT × 配布日数
SELECT
  COUNT(*) as december_days,
  SUM(profit_per_nft) as total_profit_per_nft,
  SUM(profit_per_nft) * 3 as total_personal_profit_3users
FROM daily_yield_log_v2
WHERE created_at >= '2025-12-01';

-- 5. 3ユーザーの紹介者を確認（紹介報酬の計算に必要）
SELECT
  u.user_id,
  u.email,
  u.referrer_user_id,
  r.email as referrer_email
FROM users u
LEFT JOIN users r ON u.referrer_user_id = r.user_id
WHERE u.user_id IN ('225F87', '20248A', '5A708D');

-- 6. 3ユーザーを紹介している人の確認（Level 1）
SELECT
  u.user_id,
  u.email,
  u.referrer_user_id,
  COUNT(*) OVER() as total_referrals
FROM users u
WHERE u.referrer_user_id IN ('225F87', '20248A', '5A708D');

-- 7. 紹介報酬計算（3ユーザーの紹介者への報酬）
-- Level 1: 20%, Level 2: 10%, Level 3: 5%
-- 3ユーザーの日利 × 各レベルの%
