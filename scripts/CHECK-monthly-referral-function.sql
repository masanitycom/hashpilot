-- ========================================
-- 月次紹介報酬関数の本番環境確認
-- ========================================

-- 1. process_monthly_referral_reward関数の定義を確認
SELECT '=== 1. process_monthly_referral_reward関数定義 ===' as section;
SELECT
  pg_get_functiondef(oid) as 関数定義
FROM pg_proc
WHERE proname = 'process_monthly_referral_reward';

-- 2. mark_referral_reward_calculated関数の定義を確認
SELECT '=== 2. mark_referral_reward_calculated関数定義 ===' as section;
SELECT
  pg_get_functiondef(oid) as 関数定義
FROM pg_proc
WHERE proname = 'mark_referral_reward_calculated';

-- 3. user_referral_profit_monthlyテーブルの存在確認
SELECT '=== 3. user_referral_profit_monthlyテーブル確認 ===' as section;
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'user_referral_profit_monthly'
ORDER BY ordinal_position;

-- 4. monthly_reward_tasksテーブルの構造確認
SELECT '=== 4. monthly_reward_tasksテーブル確認 ===' as section;
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'monthly_reward_tasks'
ORDER BY ordinal_position;

-- 5. 2026年1月の紹介報酬データ確認
SELECT '=== 5. 2026年1月の既存紹介報酬データ ===' as section;
SELECT
  COUNT(*) as レコード数,
  COUNT(DISTINCT user_id) as ユーザー数,
  SUM(profit_amount) as 合計報酬
FROM user_referral_profit_monthly
WHERE year = 2026 AND month = 1;

-- 6. user_daily_profitビューの確認
SELECT '=== 6. user_daily_profitビュー/テーブルの存在確認 ===' as section;
SELECT
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'user_daily_profit';
