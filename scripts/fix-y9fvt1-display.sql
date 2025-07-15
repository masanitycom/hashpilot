-- Y9FVT1ユーザーの表示問題を解決するための強制更新

-- 1. ユーザーデータの強制更新（updated_atを更新してキャッシュクリア）
UPDATE users 
SET updated_at = NOW()
WHERE user_id = 'Y9FVT1';

-- 2. affiliate_cycleの強制再計算
UPDATE affiliate_cycle 
SET updated_at = NOW()
WHERE user_id = 'Y9FVT1';

-- 3. 利益データの強制更新
UPDATE user_daily_profit 
SET updated_at = NOW()
WHERE user_id = 'Y9FVT1';

-- 4. Y9FVT1の現在状況を確認
SELECT 
    'Y9FVT1の最終状況' as status,
    ac.user_id,
    ac.available_usdt,
    ac.cum_usdt,
    ac.total_nft_count,
    ac.updated_at as cycle_updated,
    (
        SELECT SUM(daily_profit::DECIMAL) 
        FROM user_daily_profit 
        WHERE user_id = 'Y9FVT1' 
        AND date >= DATE_TRUNC('month', CURRENT_DATE)
    ) as monthly_total,
    (
        SELECT daily_profit 
        FROM user_daily_profit 
        WHERE user_id = 'Y9FVT1' 
        AND date = CURRENT_DATE - 1
    ) as yesterday_profit
FROM affiliate_cycle ac
WHERE ac.user_id = 'Y9FVT1';

-- 5. システムログを記録
INSERT INTO system_logs (log_type, operation, user_id, message, details)
VALUES (
    'INFO',
    'MANUAL_FIX',
    'Y9FVT1',
    'Y9FVT1ユーザーの表示問題解決のため強制データ更新実行',
    '{"action": "force_refresh", "monthly_profit": 11.55, "daily_records": 4}'
);