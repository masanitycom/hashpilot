-- ========================================
-- 2月分の referral_reward_calculated を設定
-- mark_referral_reward_calculated が呼ばれていなかったため手動実行
-- ========================================

-- 実行
SELECT * FROM mark_referral_reward_calculated(2026, 2);

-- 確認
SELECT '=== 修正後の確認 ===' as section;
SELECT
  year, month,
  COUNT(*) as total,
  SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) as completed,
  SUM(CASE WHEN referral_reward_calculated THEN 1 ELSE 0 END) as referral_calc
FROM monthly_reward_tasks
WHERE year = 2026 AND month = 2
GROUP BY year, month;
