-- 🚨 手動でデータを削除してから再作成
-- 2025年7月17日

-- 1. 手動で7/11データを削除
DELETE FROM user_daily_profit WHERE date = '2025-07-11';

-- 2. 削除確認
SELECT 'deletion_check' as step, COUNT(*) as remaining_records 
FROM user_daily_profit WHERE date = '2025-07-11';

-- 3. 手動で各ユーザーの利益を計算して挿入
-- 7A9637の個人利益
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, personal_profit, referral_profit, 
    yield_rate, user_rate, base_amount, phase, created_at
) VALUES (
    '7A9637', '2025-07-11', 0.658, 0.658, 0, 
    0.0011, 0.000658, 1000, 'USDT', NOW()
);

-- B43A3Dの個人利益（2NFT）
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, personal_profit, referral_profit, 
    yield_rate, user_rate, base_amount, phase, created_at
) VALUES (
    'B43A3D', '2025-07-11', 1.316, 1.316, 0, 
    0.0011, 0.000658, 2000, 'USDT', NOW()
);

-- 6E1304の個人利益 + B43A3Dからの紹介報酬（Level1: 20%）
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, personal_profit, referral_profit, 
    yield_rate, user_rate, base_amount, phase, created_at
) VALUES (
    '6E1304', '2025-07-11', 0.658 + (1.316 * 0.20), 0.658, (1.316 * 0.20), 
    0.0011, 0.000658, 1000, 'USDT', NOW()
);

-- 7A9637の紹介報酬を更新（B43A3DからのLevel2: 10%）
UPDATE user_daily_profit SET
    daily_profit = daily_profit + (1.316 * 0.10),
    referral_profit = (1.316 * 0.10)
WHERE user_id = '7A9637' AND date = '2025-07-11';

-- 4. 結果確認
SELECT 
    'final_result' as step,
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase
FROM user_daily_profit 
WHERE date = '2025-07-11'
ORDER BY daily_profit DESC;

-- 5. 紹介報酬確認
SELECT 
    'referral_check' as step,
    user_id,
    referral_profit,
    CASE 
        WHEN referral_profit > 0 THEN 'Has referral bonus'
        ELSE 'No referral bonus'
    END as status
FROM user_daily_profit 
WHERE date = '2025-07-11'
ORDER BY referral_profit DESC;