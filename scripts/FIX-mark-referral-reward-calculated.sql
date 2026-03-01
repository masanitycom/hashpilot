-- ========================================
-- mark_referral_reward_calculated 関数の修正
-- 問題: user_referral_profit_monthly（存在しない）を参照していた
-- 修正: monthly_referral_profit（正しいテーブル）を使用
-- ========================================

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
  v_year_month VARCHAR(7);
BEGIN
  -- year_month形式を作成（例: '2026-02'）
  v_year_month := p_year || '-' || LPAD(p_month::text, 2, '0');

  -- 紹介報酬を受け取ったユーザーに対してタスクレコードを作成/更新
  FOR v_user_record IN
    SELECT
      user_id,
      SUM(profit_amount) as total_referral_profit
    FROM monthly_referral_profit
    WHERE year_month = v_year_month
      AND profit_amount > 0
    GROUP BY user_id
  LOOP
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
      false,
      true,
      v_user_record.total_referral_profit,
      0
    )
    ON CONFLICT (user_id, year, month)
    DO UPDATE SET
      referral_reward_calculated = true,
      referral_reward_amount = v_user_record.total_referral_profit,
      updated_at = NOW();

    v_marked_count := v_marked_count + 1;
  END LOOP;

  RETURN v_marked_count;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION mark_referral_reward_calculated(INTEGER, INTEGER) TO authenticated;

-- 2月分を実行
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
