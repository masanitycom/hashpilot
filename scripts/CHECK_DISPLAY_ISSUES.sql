-- 🔍 表示問題の調査
-- 2025年7月17日

-- 1. 管理画面の表示確認（最新10件）
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

-- 2. 7/11のdaily_yield_logが存在するか確認
SELECT 
    '7/11_daily_yield_log存在確認' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log 
WHERE date = '2025-07-11';

-- 3. 昨日（7/16）の7A9637のLevel2紹介報酬確認
SELECT 
    '昨日のLevel2確認' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    phase
FROM user_daily_profit 
WHERE user_id = '7A9637' 
AND date = '2025-07-16';

-- 4. 7/16にB43A3Dが処理されたか確認
SELECT 
    '7/16_B43A3D処理確認' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    phase
FROM user_daily_profit 
WHERE user_id = 'B43A3D' 
AND date = '2025-07-16';

-- 5. 7A9637の全期間の紹介報酬確認
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

-- 6. 管理画面のクエリと同じ条件でテスト
SELECT 
    '管理画面同条件テスト' as check_type,
    id,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE date >= '2025-07-01'
ORDER BY date DESC;