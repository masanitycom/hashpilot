-- ========================================
-- 🚨 緊急削除：7/17の不正データ完全除去
-- 本番環境での損害防止
-- ========================================

BEGIN;

-- STEP 1: 不正データ削除前の記録
SELECT 
    '=== 🚨 削除前の状況記録 ===' as emergency_log,
    COUNT(*) as affected_users,
    SUM(daily_profit) as total_illegal_profit
FROM user_daily_profit 
WHERE date = '2025-07-17';

-- STEP 2: 7/17の不正利益データを完全削除
DELETE FROM user_daily_profit WHERE date = '2025-07-17';

-- STEP 3: 7/17の不正設定を完全削除
DELETE FROM daily_yield_log WHERE date = '2025-07-17';

-- STEP 4: affiliate_cycleの巻き戻し（必要に応じて）
-- 注意: cum_usdtとavailable_usdtから不正利益分を減算
UPDATE affiliate_cycle 
SET 
    cum_usdt = cum_usdt - (
        SELECT COALESCE(daily_profit, 0)
        FROM user_daily_profit udp 
        WHERE udp.user_id = affiliate_cycle.user_id 
        AND udp.date = '2025-07-17'
    ),
    available_usdt = available_usdt - (
        SELECT COALESCE(daily_profit, 0)
        FROM user_daily_profit udp 
        WHERE udp.user_id = affiliate_cycle.user_id 
        AND udp.date = '2025-07-17'
    ),
    updated_at = NOW()
WHERE user_id IN (
    SELECT DISTINCT user_id 
    FROM user_daily_profit 
    WHERE date = '2025-07-17'
);

-- STEP 5: システムログに緊急対応を記録
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
)
VALUES (
    'EMERGENCY',
    'DATA_DELETION',
    'SYSTEM_ADMIN',
    '7/17不正データの緊急削除実行',
    jsonb_build_object(
        'deleted_date', '2025-07-17',
        'reason', '設定なしの日付で不正処理が実行された',
        'action', '全データ削除とaffiliate_cycle巻き戻し',
        'execution_time', NOW()
    ),
    NOW()
);

-- STEP 6: 削除結果確認
SELECT 
    '=== ✅ 削除結果確認 ===' as cleanup_result,
    (SELECT COUNT(*) FROM user_daily_profit WHERE date = '2025-07-17') as remaining_profit_data,
    (SELECT COUNT(*) FROM daily_yield_log WHERE date = '2025-07-17') as remaining_yield_settings;

-- STEP 7: 安全確認メッセージ
SELECT 
    '🚨 緊急削除完了 🚨' as status,
    '7/17の不正データを完全除去しました' as message,
    '次のステップ: 自動処理の特定と停止' as next_action;

COMMIT;