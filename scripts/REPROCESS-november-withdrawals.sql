-- ========================================
-- 11月の月末出金処理を再実行
-- ========================================
-- 背景:
--   - process_monthly_withdrawals が available_usdt >= 100 で処理していた
--   - 58名が対象だったが、2名しか処理されなかった（56名が除外）
--
-- このスクリプトの実行手順:
--   1. 既存の2件のレコードを削除
--   2. 関数を修正（FIX-monthly-withdrawals-minimum-amount.sql）
--   3. このスクリプトで11月分を再処理
-- ========================================

-- STEP 1: 既存のレコード確認
SELECT '=== STEP 1: 既存のレコード確認 ===' as step;

SELECT
    user_id,
    email,
    total_amount,
    withdrawal_method,
    withdrawal_address,
    status,
    task_completed,
    created_at
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
ORDER BY created_at;

-- 既存レコード数
SELECT
    COUNT(*) as existing_count,
    SUM(total_amount) as existing_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01';

-- STEP 2: 既存のタスクレコード確認
SELECT '=== STEP 2: 既存のタスクレコード確認 ===' as step;

SELECT
    COUNT(*) as task_record_count
FROM monthly_reward_tasks
WHERE year = 2025 AND month = 11;

-- STEP 3: 既存レコードを削除（再処理のため）
SELECT '=== STEP 3: 既存レコードを削除 ===' as step;

-- 出金レコードを削除
DELETE FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01';

-- タスクレコードを削除
DELETE FROM monthly_reward_tasks
WHERE year = 2025 AND month = 11;

-- 削除完了確認
SELECT
    'monthly_withdrawals' as table_name,
    COUNT(*) as remaining_count
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
UNION ALL
SELECT
    'monthly_reward_tasks' as table_name,
    COUNT(*) as remaining_count
FROM monthly_reward_tasks
WHERE year = 2025 AND month = 11;

-- STEP 4: 11月分を再処理
SELECT '=== STEP 4: 11月分を再処理 ===' as step;

SELECT * FROM process_monthly_withdrawals('2025-11-01'::DATE);

-- STEP 5: 結果確認
SELECT '=== STEP 5: 結果確認 ===' as step;

-- 出金レコード数と総額
SELECT
    COUNT(*) as new_withdrawal_count,
    SUM(total_amount) as new_total_amount,
    MIN(total_amount) as min_amount,
    MAX(total_amount) as max_amount,
    AVG(total_amount) as avg_amount
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01';

-- 出金方法別の集計
SELECT
    withdrawal_method,
    COUNT(*) as count,
    SUM(total_amount) as total_amount
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
GROUP BY withdrawal_method
ORDER BY withdrawal_method;

-- タスクレコード数
SELECT
    COUNT(*) as task_count,
    COUNT(*) FILTER (WHERE is_completed = true) as completed_count,
    COUNT(*) FILTER (WHERE is_completed = false) as pending_count
FROM monthly_reward_tasks
WHERE year = 2025 AND month = 11;

-- STEP 6: ステータス別の集計
SELECT '=== STEP 6: ステータス別の集計 ===' as step;

SELECT
    status,
    task_completed,
    COUNT(*) as count,
    SUM(total_amount) as total_amount
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
GROUP BY status, task_completed
ORDER BY status, task_completed;

-- STEP 7: 除外されたユーザー確認（ペガサス制限）
SELECT '=== STEP 7: 除外されたユーザー確認（ペガサス制限） ===' as step;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.available_usdt,
    u.is_pegasus_exchange,
    u.pegasus_withdrawal_unlock_date,
    CASE
        WHEN u.pegasus_withdrawal_unlock_date IS NULL THEN '制限期間終了日未設定'
        WHEN CURRENT_DATE < u.pegasus_withdrawal_unlock_date THEN '制限期間中（' || u.pegasus_withdrawal_unlock_date || 'まで）'
        ELSE '制限期間終了'
    END as restriction_status
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND u.is_pegasus_exchange = true
  AND (
      u.pegasus_withdrawal_unlock_date IS NULL
      OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
  )
ORDER BY ac.available_usdt DESC;

-- STEP 8: 最終確認メッセージ
DO $$
DECLARE
    v_count INTEGER;
    v_total NUMERIC;
BEGIN
    SELECT COUNT(*), SUM(total_amount)
    INTO v_count, v_total
    FROM monthly_withdrawals
    WHERE withdrawal_month = '2025-11-01';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 11月の月末出金処理を再実行しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '処理結果:';
    RAISE NOTICE '  - 出金申請レコード: %件', v_count;
    RAISE NOTICE '  - 総額: $%', v_total;
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. ダッシュボードで報酬タスクポップアップが表示されることを確認';
    RAISE NOTICE '  2. 管理画面 /admin/withdrawals で全てのレコードが表示されることを確認';
    RAISE NOTICE '===========================================';
END $$;
