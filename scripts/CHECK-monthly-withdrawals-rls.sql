-- ========================================
-- monthly_withdrawals のRLSとタスクポップアップ調査
-- ========================================

-- 1. RLSが有効か確認
SELECT '=== 1. monthly_withdrawals RLS状態 ===' as section;
SELECT
  relname as table_name,
  relrowsecurity as rls_enabled,
  relforcerowsecurity as rls_forced
FROM pg_class
WHERE relname = 'monthly_withdrawals';

-- 2. RLSポリシー一覧
SELECT '=== 2. monthly_withdrawals ポリシー ===' as section;
SELECT
  policyname,
  permissive,
  roles,
  cmd,
  qual::text as using_condition,
  with_check::text as with_check_condition
FROM pg_policies
WHERE tablename = 'monthly_withdrawals';

-- 3. monthly_reward_tasks のRLS状態
SELECT '=== 3. monthly_reward_tasks RLS状態 ===' as section;
SELECT
  relname as table_name,
  relrowsecurity as rls_enabled
FROM pg_class
WHERE relname = 'monthly_reward_tasks';

-- 4. monthly_reward_tasks ポリシー
SELECT '=== 4. monthly_reward_tasks ポリシー ===' as section;
SELECT
  policyname,
  permissive,
  roles,
  cmd,
  qual::text as using_condition
FROM pg_policies
WHERE tablename = 'monthly_reward_tasks';

-- 5. 2月のmonthly_reward_tasksレコード確認
SELECT '=== 5. monthly_reward_tasks (2月) ===' as section;
SELECT
  year, month,
  COUNT(*) as total,
  SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) as completed,
  SUM(CASE WHEN referral_reward_calculated THEN 1 ELSE 0 END) as referral_calc
FROM monthly_reward_tasks
WHERE year = 2026 AND month = 2
GROUP BY year, month;

-- 6. on_holdの出金レコード（サンプル5件）
SELECT '=== 6. on_hold出金レコード（サンプル） ===' as section;
SELECT user_id, status, task_completed, withdrawal_month
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-02-01'
  AND status = 'on_hold'
LIMIT 5;
