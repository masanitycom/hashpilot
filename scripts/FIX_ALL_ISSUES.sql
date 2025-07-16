-- 🚨 7/11と7/16の問題を一括修正
-- 2025年7月17日

-- 1. 7/11のdaily_yield_logを復元
INSERT INTO daily_yield_log (
    date, yield_rate, margin_rate, user_rate, is_month_end, created_at
) VALUES (
    '2025-07-11', 0.0011, 0.30, 0.000658, false, '2025-07-13 04:23:34.268802+00'
) ON CONFLICT (date) DO NOTHING;

-- 2. 7/16のB43A3Dデータを確認
SELECT 
    '7/16_B43A3D確認' as check_type,
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    phase
FROM user_daily_profit 
WHERE user_id = 'B43A3D' AND date = '2025-07-16';

-- 3. 7/16の全データを削除して再処理
DELETE FROM user_daily_profit WHERE date = '2025-07-16';

-- 4. 7/16のB43A3Dの個人利益を追加（2NFT × 0.000718 = 1.436）
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, personal_profit, referral_profit, 
    yield_rate, user_rate, base_amount, phase, created_at
) VALUES (
    'B43A3D', '2025-07-16', 1.436, 1.436, 0, 
    0.0012, 0.000718, 2000, 'USDT', NOW()
);

-- 5. 7A9637の個人利益を追加（1NFT × 0.000718 = 0.718）
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, personal_profit, referral_profit, 
    yield_rate, user_rate, base_amount, phase, created_at
) VALUES (
    '7A9637', '2025-07-16', 0.718, 0.718, 0, 
    0.0012, 0.000718, 1000, 'USDT', NOW()
);

-- 6. 6E1304の個人利益を追加（1NFT × 0.000718 = 0.718）
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, personal_profit, referral_profit, 
    yield_rate, user_rate, base_amount, phase, created_at
) VALUES (
    '6E1304', '2025-07-16', 0.718, 0.718, 0, 
    0.0012, 0.000718, 1000, 'USDT', NOW()
);

-- 7. 6E1304にB43A3DからのLevel1紹介報酬を追加（1.436 × 20% = 0.287）
UPDATE user_daily_profit SET
    daily_profit = daily_profit + (1.436 * 0.20),
    referral_profit = referral_profit + (1.436 * 0.20)
WHERE user_id = '6E1304' AND date = '2025-07-16';

-- 8. 7A9637にB43A3DからのLevel2紹介報酬を追加（1.436 × 10% = 0.144）
UPDATE user_daily_profit SET
    daily_profit = daily_profit + (1.436 * 0.10),
    referral_profit = referral_profit + (1.436 * 0.10)
WHERE user_id = '7A9637' AND date = '2025-07-16';

-- 9. 修正結果確認
SELECT 
    '修正後_7/16結果' as check_type,
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase
FROM user_daily_profit 
WHERE date = '2025-07-16'
ORDER BY daily_profit DESC;

-- 10. 管理画面表示確認
SELECT 
    '管理画面表示確認' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

-- 11. 7A9637の紹介報酬履歴確認
SELECT 
    '7A9637紹介報酬履歴' as check_type,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    phase
FROM user_daily_profit 
WHERE user_id = '7A9637'
AND date >= '2025-07-10'
ORDER BY date DESC;