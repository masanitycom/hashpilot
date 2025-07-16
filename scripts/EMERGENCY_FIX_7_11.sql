-- 🚨 7/11データの緊急修正
-- 2025年7月17日

-- 1. 7/11の全データを強制削除
DELETE FROM user_daily_profit WHERE date = '2025-07-11';

-- 2. 削除確認
SELECT COUNT(*) FROM user_daily_profit WHERE date = '2025-07-11';

-- 3. 個別削除（念のため）
DELETE FROM user_daily_profit WHERE user_id = '7A9637' AND date = '2025-07-11';
DELETE FROM user_daily_profit WHERE user_id = 'B43A3D' AND date = '2025-07-11';
DELETE FROM user_daily_profit WHERE user_id = '6E1304' AND date = '2025-07-11';

-- 4. 7/11を新しい紹介報酬付き関数で再実行
SELECT * FROM process_daily_yield_with_cycles('2025-07-11'::date, 0.0011, 30, false, false);

-- 5. 処理結果確認
SELECT 
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase
FROM user_daily_profit 
WHERE date = '2025-07-11'
ORDER BY daily_profit DESC;

-- 6. 紹介報酬確認
SELECT 
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    CASE 
        WHEN referral_profit > 0 THEN '紹介報酬あり'
        ELSE '個人利益のみ'
    END as reward_type
FROM user_daily_profit 
WHERE date = '2025-07-11'
AND (referral_profit > 0 OR personal_profit > 0)
ORDER BY referral_profit DESC;

-- 7. システムログ確認
SELECT 
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%daily_yield%'
AND details->>'date' = '2025-07-11'
ORDER BY created_at DESC
LIMIT 3;