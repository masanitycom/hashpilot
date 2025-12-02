-- ========================================
-- 【ワンステップ】11月分の月末出金レコードを作成
-- ========================================
--
-- このスクリプトを実行すると:
-- 1. available_usdt >= $10のユーザーに出金レコードを作成
-- 2. ユーザーがダッシュボードにアクセスするとタスクポップアップが自動表示
-- 3. タスク完了後、管理画面で送金処理が可能になる
--
-- ========================================

-- 11月分の月末出金レコードを作成
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
    'on_hold' as status,
    false as task_completed,
    '2025年11月分 月末出金' as notes,
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
    -- 既に11月の出金レコードがあるユーザーを除外（重複防止）
    AND NOT EXISTS (
        SELECT 1 FROM monthly_withdrawals mw
        WHERE mw.user_id = ac.user_id
            AND mw.withdrawal_month = '2025-11-01'
    );

-- 結果を表示
SELECT
    '✅ 出金レコード作成完了' as ステータス,
    COUNT(*) as 作成件数,
    SUM(total_amount) as 出金予定総額
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
    AND created_at >= NOW() - INTERVAL '1 minute';

-- 詳細リスト
SELECT
    mw.user_id,
    u.email,
    CONCAT('$', mw.total_amount) as 出金予定額,
    mw.withdrawal_address as CoinW_UID,
    mw.status as ステータス,
    '次回ログイン時にタスク表示' as 備考
FROM monthly_withdrawals mw
INNER JOIN users u ON mw.user_id = u.user_id
WHERE mw.withdrawal_month = '2025-11-01'
    AND mw.created_at >= NOW() - INTERVAL '1 minute'
ORDER BY mw.total_amount DESC;
