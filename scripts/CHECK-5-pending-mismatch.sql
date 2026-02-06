-- ========================================
-- pending出金との不一致5名の確認
-- ========================================

SELECT '=== 不一致の5名 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(mw.personal_amount::numeric, 2) as pending_personal,
  ROUND((ac.available_usdt - mw.personal_amount)::numeric, 2) as diff,
  mw.withdrawal_month,
  mw.status
FROM affiliate_cycle ac
JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
WHERE mw.status = 'pending'
  AND ABS(ac.available_usdt - mw.personal_amount) >= 0.01
ORDER BY ABS(ac.available_usdt - mw.personal_amount) DESC;

-- 複数のpending出金があるか確認
SELECT '=== 複数pending出金の有無 ===' as section;
SELECT
  user_id,
  COUNT(*) as pending_count
FROM monthly_withdrawals
WHERE status = 'pending'
GROUP BY user_id
HAVING COUNT(*) > 1;
