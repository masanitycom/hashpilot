-- ========================================
-- 紹介報酬計算完了時のタスクシステム
-- ========================================
--
-- 月末の紹介報酬計算が完了したら、ユーザーダッシュボードに
-- タスクポップアップを表示する仕組み
--
-- 既存の monthly_reward_tasks テーブルと reward_questions を活用
-- ========================================

-- 1. monthly_reward_tasks テーブルに紹介報酬計算完了フラグを追加
ALTER TABLE monthly_reward_tasks
ADD COLUMN IF NOT EXISTS referral_reward_calculated BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS referral_reward_amount NUMERIC DEFAULT 0;

-- 2. インデックス追加
CREATE INDEX IF NOT EXISTS idx_monthly_reward_tasks_referral_calculated
ON monthly_reward_tasks(user_id, year, month, referral_reward_calculated, is_completed);

-- 3. 紹介報酬計算完了を記録する関数
-- process_monthly_referral_reward 実行後に呼び出される
CREATE OR REPLACE FUNCTION mark_referral_reward_calculated(
  p_year INTEGER,
  p_month INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_record RECORD;
  v_marked_count INTEGER := 0;
  v_total_referral_amount NUMERIC;
BEGIN
  -- 紹介報酬を受け取ったユーザーに対してタスクレコードを作成/更新
  FOR v_user_record IN
    SELECT
      user_id,
      SUM(profit_amount) as total_referral_profit
    FROM user_referral_profit_monthly
    WHERE year = p_year
      AND month = p_month
      AND profit_amount > 0
    GROUP BY user_id
  LOOP
    v_total_referral_amount := v_user_record.total_referral_profit;

    -- タスクレコードを作成または更新
    INSERT INTO monthly_reward_tasks (
      user_id,
      year,
      month,
      is_completed,
      referral_reward_calculated,
      referral_reward_amount,
      questions_answered
    )
    VALUES (
      v_user_record.user_id,
      p_year,
      p_month,
      false,  -- タスク未完了
      true,   -- 紹介報酬計算済み
      v_total_referral_amount,
      0
    )
    ON CONFLICT (user_id, year, month)
    DO UPDATE SET
      referral_reward_calculated = true,
      referral_reward_amount = v_total_referral_amount,
      updated_at = NOW();

    v_marked_count := v_marked_count + 1;
  END LOOP;

  RETURN v_marked_count;
END;
$$;

-- 4. ユーザーの紹介報酬タスク状況を取得する関数
CREATE OR REPLACE FUNCTION get_referral_reward_task_status(
  p_user_id VARCHAR(10)
)
RETURNS TABLE(
  has_pending_task BOOLEAN,
  year INTEGER,
  month INTEGER,
  referral_amount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    true as has_pending_task,
    mrt.year,
    mrt.month,
    mrt.referral_reward_amount
  FROM monthly_reward_tasks mrt
  WHERE mrt.user_id = p_user_id
    AND mrt.referral_reward_calculated = true  -- 紹介報酬計算済み
    AND mrt.is_completed = false               -- タスク未完了
  ORDER BY mrt.year DESC, mrt.month DESC
  LIMIT 1;
END;
$$;

-- 5. 実行権限付与
GRANT EXECUTE ON FUNCTION mark_referral_reward_calculated(INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_reward_task_status(VARCHAR) TO authenticated;

-- 6. 確認クエリ
SELECT 'Referral reward task system created successfully' as status;

-- 使用方法:
-- 1. process_monthly_referral_reward() 実行後に以下を実行
--    SELECT mark_referral_reward_calculated(2025, 11);
--
-- 2. ユーザーダッシュボードで以下をチェック
--    SELECT * FROM get_referral_reward_task_status('177B83');
--
-- 3. タスク完了時は既存の complete_reward_task() を使用
--    SELECT complete_reward_task('177B83', '[{"question_id": "...", "answer": "A"}]');
