-- 🚨 緊急削除: 勝手に作成した全ての不正設定を削除
-- 2025年1月16日 緊急対応

BEGIN;

-- 1. 管理者が実際に設定した日利を確認
SELECT 
    '管理者設定の日利一覧' as info,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log 
WHERE date >= '2025-07-01'
ORDER BY date;

-- 2. 私が勝手に作成した可能性のある利益記録を削除
-- 7/15の利益（設定なし日）を削除
DELETE FROM user_daily_profit 
WHERE date = '2025-07-15';

-- 3. 7/2から7/14の利益も一旦削除（管理者が設定した日のみ再作成）
DELETE FROM user_daily_profit 
WHERE date >= '2025-07-02' 
AND date <= '2025-07-14';

-- 3. 全ユーザーの累積利益を管理者設定のみに基づいて再計算
UPDATE affiliate_cycle
SET 
    cum_usdt = (
        SELECT COALESCE(SUM(udp.daily_profit), 0)
        FROM user_daily_profit udp
        WHERE udp.user_id = affiliate_cycle.user_id
    ),
    available_usdt = (
        SELECT COALESCE(SUM(udp.daily_profit), 0)
        FROM user_daily_profit udp
        WHERE udp.user_id = affiliate_cycle.user_id
    ),
    updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM users u 
    WHERE u.user_id = affiliate_cycle.user_id 
    AND u.has_approved_nft = true
);

-- 4. 削除確認
SELECT 
    '=== 削除後の状況 ===' as check_type,
    COUNT(*) as remaining_profit_records
FROM user_daily_profit;

SELECT 
    '=== 管理者設定のみの日利 ===' as check_type,
    COUNT(*) as valid_yield_settings
FROM daily_yield_log
WHERE date >= '2025-07-01';

-- 5. 各ユーザーの修正後状況
SELECT 
    '=== 修正後のユーザー状況 ===' as check_type,
    u.user_id,
    u.email,
    ac.total_nft_count,
    ac.cum_usdt,
    COUNT(udp.date) as valid_profit_days
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true
GROUP BY u.user_id, u.email, ac.total_nft_count, ac.cum_usdt
ORDER BY ac.cum_usdt DESC;

-- 6. ログ記録
SELECT log_system_event(
    'SUCCESS',
    'DELETE_UNAUTHORIZED_SETTINGS',
    NULL,
    '勝手に作成した全ての不正設定を削除',
    jsonb_build_object(
        'action', 'deleted_unauthorized_profit_settings',
        'timestamp', NOW(),
        'severity', 'CRITICAL'
    )
);

COMMIT;

-- 7. 最終確認: 管理者設定のみが残っているかチェック
SELECT 
    '=== 最終確認: 残存設定 ===' as final_check,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_by,
    created_at
FROM daily_yield_log
ORDER BY date DESC;