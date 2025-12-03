-- ========================================
-- complete_reward_task関数の修正
-- monthly_withdrawalsのstatusをon_hold→pendingに変更する
-- ========================================

-- 修正版: タスク完了時にstatusも更新
CREATE OR REPLACE FUNCTION complete_reward_task(p_user_id VARCHAR(10), p_answers JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_year INTEGER;
    v_current_month INTEGER;
    v_prev_year INTEGER;
    v_prev_month INTEGER;
    v_task_exists BOOLEAN;
BEGIN
    -- 現在の年月を取得（日本時間）
    v_current_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'Asia/Tokyo'));
    v_current_month := EXTRACT(MONTH FROM (NOW() AT TIME ZONE 'Asia/Tokyo'));

    -- 前月を計算（タスクは前月分の可能性もある）
    IF v_current_month = 1 THEN
        v_prev_year := v_current_year - 1;
        v_prev_month := 12;
    ELSE
        v_prev_year := v_current_year;
        v_prev_month := v_current_month - 1;
    END IF;

    -- タスクレコードの存在確認（現在月または前月）
    SELECT EXISTS(
        SELECT 1 FROM monthly_reward_tasks
        WHERE user_id = p_user_id
        AND ((year = v_current_year AND month = v_current_month)
             OR (year = v_prev_year AND month = v_prev_month))
        AND is_completed = false
    ) INTO v_task_exists;

    IF NOT v_task_exists THEN
        -- タスクレコードが存在しない場合は作成（前月分として）
        INSERT INTO monthly_reward_tasks (
            user_id, year, month, is_completed, questions_answered, answers, completed_at
        )
        VALUES (
            p_user_id, v_prev_year, v_prev_month, true,
            jsonb_array_length(p_answers), p_answers, NOW()
        )
        ON CONFLICT (user_id, year, month) DO UPDATE SET
            is_completed = true,
            questions_answered = jsonb_array_length(p_answers),
            answers = p_answers,
            completed_at = NOW(),
            updated_at = NOW();
    ELSE
        -- 既存のタスクを完了状態に更新（現在月または前月）
        UPDATE monthly_reward_tasks
        SET
            is_completed = true,
            questions_answered = jsonb_array_length(p_answers),
            answers = p_answers,
            completed_at = NOW(),
            updated_at = NOW()
        WHERE user_id = p_user_id
        AND ((year = v_current_year AND month = v_current_month)
             OR (year = v_prev_year AND month = v_prev_month))
        AND is_completed = false;
    END IF;

    -- 対応する出金レコードも更新（status を on_hold → pending に変更）
    UPDATE monthly_withdrawals
    SET
        task_completed = true,
        task_completed_at = NOW(),
        status = 'pending'  -- ★ ここが重要！
    WHERE user_id = p_user_id
    AND status = 'on_hold'
    AND task_completed = false;

    RETURN true;
END;
$$;

-- 確認用クエリ
SELECT 'complete_reward_task function updated to change status from on_hold to pending' as result;
