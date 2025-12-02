-- ========================================
-- 【手動】月末出金レコードを作成してタスクポップアップを表示
-- ========================================
--
-- 使い方:
-- 1. 紹介報酬を手動で計算完了
-- 2. このスクリプトを実行
-- 3. ユーザーがダッシュボードにアクセスするとタスクポップアップが表示される
--
-- ========================================

-- STEP 1: 対象ユーザーの確認（available_usdt >= $10のユーザー）
SELECT
    '【確認】出金対象ユーザー' as step,
    ac.user_id,
    u.email,
    ac.available_usdt as 出金予定額,
    u.coinw_uid as 送金先CoinW_UID,
    CASE
        WHEN u.is_pegasus_exchange = true
            AND u.pegasus_withdrawal_unlock_date IS NOT NULL
            AND u.pegasus_withdrawal_unlock_date > CURRENT_DATE
        THEN '制限中'
        ELSE 'OK'
    END as ペガサス制限状況
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE ac.available_usdt >= 10
    -- ペガサス出金制限中のユーザーを除外
    AND NOT (
        u.is_pegasus_exchange = true
        AND u.pegasus_withdrawal_unlock_date IS NOT NULL
        AND u.pegasus_withdrawal_unlock_date > CURRENT_DATE
    )
    -- 既に11月の出金レコードがあるユーザーを除外
    AND NOT EXISTS (
        SELECT 1 FROM monthly_withdrawals mw
        WHERE mw.user_id = ac.user_id
            AND mw.withdrawal_month = '2025-11-01'
    )
ORDER BY ac.available_usdt DESC;

-- STEP 2: 出金レコード作成（実行前に必ず上記の確認を行ってください）
-- ⚠️ このINSERT文を実行すると、対象ユーザー全員に出金レコードが作成されます

INSERT INTO monthly_withdrawals (
    user_id,
    withdrawal_month,
    total_amount,
    withdrawal_address,
    withdrawal_method,
    status,
    task_completed,
    notes,
    created_at
)
SELECT
    ac.user_id,
    '2025-11-01' as withdrawal_month,
    ac.available_usdt as total_amount,
    u.coinw_uid as withdrawal_address,
    'coinw' as withdrawal_method,
    'on_hold' as status,  -- タスク未完了状態
    false as task_completed,
    '手動作成：紹介報酬計算完了後' as notes,
    NOW() as created_at
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE ac.available_usdt >= 10
    -- ペガサス出金制限中のユーザーを除外
    AND NOT (
        u.is_pegasus_exchange = true
        AND u.pegasus_withdrawal_unlock_date IS NOT NULL
        AND u.pegasus_withdrawal_unlock_date > CURRENT_DATE
    )
    -- 既に11月の出金レコードがあるユーザーを除外
    AND NOT EXISTS (
        SELECT 1 FROM monthly_withdrawals mw
        WHERE mw.user_id = ac.user_id
            AND mw.withdrawal_month = '2025-11-01'
    );

-- STEP 3: 作成された出金レコードの確認
SELECT
    '【確認】作成された出金レコード' as step,
    mw.id,
    mw.user_id,
    u.email,
    mw.total_amount as 出金予定額,
    mw.withdrawal_address as CoinW_UID,
    mw.status,
    mw.task_completed,
    mw.created_at
FROM monthly_withdrawals mw
INNER JOIN users u ON mw.user_id = u.user_id
WHERE mw.withdrawal_month = '2025-11-01'
ORDER BY mw.created_at DESC;

-- STEP 4: タスクポップアップ表示の動作確認
-- このクエリで status = 'on_hold' AND task_completed = false のレコードがあれば、
-- ユーザーがダッシュボードにアクセスした際にタスクポップアップが表示されます
SELECT
    '【確認】タスクポップアップ対象ユーザー' as step,
    COUNT(*) as 対象ユーザー数
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
    AND status = 'on_hold'
    AND task_completed = false;

-- ========================================
-- 注意事項
-- ========================================
--
-- 1. STEP 1で対象ユーザーを必ず確認してからSTEP 2を実行してください
-- 2. STEP 2は一度だけ実行してください（重複レコード防止）
-- 3. ユーザーがタスクを完了すると、自動的に status が 'on_hold' → 'pending' に変更されます
-- 4. 管理者が送金完了後、管理画面で「完了済みにする」をクリックすると status が 'pending' → 'completed' になります
--
-- ========================================
