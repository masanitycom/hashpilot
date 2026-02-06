-- ========================================
-- $10未満ユーザーの出金レコード作成
-- ========================================
-- 目的: 出金管理画面に$10未満のユーザーも表示する
-- ステータス: 'under_minimum' で区別
-- ========================================

-- STEP 1: 現在の状態確認
SELECT '=== STEP 1: 現在の1月出金レコード数 ===' as section;
SELECT
  COUNT(*) as total_records,
  COUNT(CASE WHEN total_amount >= 10 THEN 1 END) as over_10,
  COUNT(CASE WHEN total_amount < 10 THEN 1 END) as under_10
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01';

-- STEP 2: $10未満の対象ユーザーを確認
SELECT '=== STEP 2: $10未満の対象ユーザー ===' as section;
WITH january_profit AS (
  SELECT
    user_id,
    SUM(daily_profit) as personal_amount
  FROM nft_daily_profit
  WHERE date >= '2026-01-01' AND date <= '2026-01-31'
  GROUP BY user_id
),
existing_withdrawals AS (
  SELECT user_id FROM monthly_withdrawals WHERE withdrawal_month = '2026-01-01'
)
SELECT
  jp.user_id,
  ROUND(jp.personal_amount::numeric, 2) as personal_amount,
  ac.phase,
  CASE
    WHEN ac.phase = 'USDT' THEN ROUND((ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    ELSE 0
  END as referral_amount
FROM january_profit jp
JOIN affiliate_cycle ac ON jp.user_id = ac.user_id
LEFT JOIN existing_withdrawals ew ON jp.user_id = ew.user_id
WHERE ew.user_id IS NULL  -- まだ出金レコードがない
  AND jp.personal_amount > 0  -- 個人利益がプラス
ORDER BY jp.personal_amount DESC;

-- STEP 3: $10未満レコードを作成
SELECT '=== STEP 3: $10未満レコードを作成 ===' as section;
WITH january_profit AS (
  SELECT
    user_id,
    SUM(daily_profit) as personal_amount
  FROM nft_daily_profit
  WHERE date >= '2026-01-01' AND date <= '2026-01-31'
  GROUP BY user_id
),
existing_withdrawals AS (
  SELECT user_id FROM monthly_withdrawals WHERE withdrawal_month = '2026-01-01'
),
users_to_add AS (
  SELECT
    jp.user_id,
    ROUND(jp.personal_amount::numeric, 2) as personal_amount,
    CASE
      WHEN ac.phase = 'USDT' THEN ROUND((ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
      ELSE 0
    END as referral_amount
  FROM january_profit jp
  JOIN affiliate_cycle ac ON jp.user_id = ac.user_id
  LEFT JOIN existing_withdrawals ew ON jp.user_id = ew.user_id
  WHERE ew.user_id IS NULL
    AND jp.personal_amount > 0
)
INSERT INTO monthly_withdrawals (
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status,
  task_completed,
  created_at,
  updated_at
)
SELECT
  user_id,
  '2026-01-01'::date,
  personal_amount,
  referral_amount,
  personal_amount + referral_amount,
  'under_minimum',  -- 特別ステータス
  false,
  NOW(),
  NOW()
FROM users_to_add
WHERE personal_amount + referral_amount < 10;

-- STEP 4: 結果確認
SELECT '=== STEP 4: 作成後の状態 ===' as section;
SELECT
  status,
  COUNT(*) as count,
  SUM(total_amount) as total
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
GROUP BY status
ORDER BY status;

-- STEP 5: $10未満ユーザー一覧
SELECT '=== STEP 5: $10未満ユーザー一覧 ===' as section;
SELECT
  user_id,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND status = 'under_minimum'
ORDER BY total_amount DESC;
