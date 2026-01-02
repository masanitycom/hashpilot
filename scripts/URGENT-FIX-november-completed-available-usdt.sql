-- ========================================
-- 緊急修正: 11月完了済みユーザーのavailable_usdtをリセット
-- ========================================
-- 問題: 11月の出金を「完了済み」にしたが、available_usdtが減算されていない
-- 結果: 12月の出金額に11月分が二重で含まれている
-- ========================================

-- ========================================
-- STEP 1: 現状確認 - 11月完了済みの問題ユーザー
-- ========================================
SELECT '=== STEP 1: 11月完了済みで二重計上の疑いがあるユーザー ===' as section;
SELECT
  mw11.user_id,
  mw11.total_amount as nov_paid,
  ac.available_usdt as current_available,
  mw12.total_amount as dec_withdrawal,
  mw12.personal_amount as dec_personal,
  mw12.referral_amount as dec_referral
FROM monthly_withdrawals mw11
JOIN affiliate_cycle ac ON mw11.user_id = ac.user_id
LEFT JOIN monthly_withdrawals mw12 ON mw11.user_id = mw12.user_id AND mw12.withdrawal_month = '2025-12-01'
WHERE mw11.withdrawal_month = '2025-11-01'
  AND mw11.status = 'completed'
ORDER BY mw11.total_amount DESC
LIMIT 20;

-- ========================================
-- STEP 2: 11月完了済みユーザーのavailable_usdtをリセット
-- available_usdt = 12月の日利のみにする
-- ========================================
SELECT '=== STEP 2: available_usdtを12月日利のみにリセット ===' as section;

-- 11月完了済みユーザーのavailable_usdtを12月の日利だけにする
UPDATE affiliate_cycle ac
SET
  available_usdt = COALESCE(dec_profit.total, 0),
  updated_at = NOW()
FROM (
  SELECT user_id
  FROM monthly_withdrawals
  WHERE withdrawal_month = '2025-11-01'
    AND status = 'completed'
) completed_nov
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  WHERE date >= '2025-12-01'
  GROUP BY user_id
) dec_profit ON completed_nov.user_id = dec_profit.user_id
WHERE ac.user_id = completed_nov.user_id;

-- ========================================
-- STEP 3: 12月の出金レコードを再作成（削除→再作成）
-- ========================================
SELECT '=== STEP 3: 12月出金レコードを削除 ===' as section;

-- 11月完了済みユーザーの12月出金レコードを削除
DELETE FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
  AND user_id IN (
    SELECT user_id
    FROM monthly_withdrawals
    WHERE withdrawal_month = '2025-11-01'
      AND status = 'completed'
  );

-- ========================================
-- STEP 4: 12月の出金レコードを再作成
-- ========================================
SELECT '=== STEP 4: 12月出金レコードを再作成 ===' as section;

-- process_monthly_withdrawalsを再実行（12月分）
SELECT * FROM process_monthly_withdrawals('2025-12-01'::DATE);

-- ========================================
-- STEP 5: 12月の内訳を正しく設定
-- ========================================
SELECT '=== STEP 5: 12月内訳を設定 ===' as section;

-- personal_amountを12月の日利で更新
UPDATE monthly_withdrawals mw
SET
  personal_amount = COALESCE(daily.dec_personal, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(daily_profit) as dec_personal
  FROM nft_daily_profit
  WHERE date >= '2025-12-01' AND date < '2026-01-01'
  GROUP BY user_id
) daily
WHERE mw.user_id = daily.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- referral_amountを12月の紹介報酬で更新
UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(referral.dec_referral, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as dec_referral
  FROM user_referral_profit_monthly
  WHERE year = 2025 AND month = 12
  GROUP BY user_id
) referral
WHERE mw.user_id = referral.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- NULLを0に
UPDATE monthly_withdrawals
SET referral_amount = 0
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount IS NULL;

-- ========================================
-- STEP 6: 結果確認
-- ========================================
SELECT '=== STEP 6: 修正後の確認 ===' as section;
SELECT
  mw12.user_id,
  mw11.total_amount as nov_paid,
  mw11.status as nov_status,
  mw12.total_amount as dec_total,
  mw12.personal_amount as dec_personal,
  mw12.referral_amount as dec_referral,
  ac.available_usdt as current_available
FROM monthly_withdrawals mw12
LEFT JOIN monthly_withdrawals mw11 ON mw12.user_id = mw11.user_id AND mw11.withdrawal_month = '2025-11-01'
JOIN affiliate_cycle ac ON mw12.user_id = ac.user_id
WHERE mw12.withdrawal_month = '2025-12-01'
ORDER BY mw12.total_amount DESC
LIMIT 20;

-- ========================================
-- STEP 7: 統計情報
-- ========================================
SELECT '=== STEP 7: 12月統計 ===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(total_amount) as total_withdrawal,
  SUM(personal_amount) as personal_total,
  SUM(referral_amount) as referral_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 8: 11月未払いユーザー一覧
-- ========================================
SELECT '=== STEP 8: 11月未払いユーザー ===' as section;
SELECT
  user_id,
  total_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
  AND status IN ('pending', 'on_hold')
ORDER BY total_amount DESC;
