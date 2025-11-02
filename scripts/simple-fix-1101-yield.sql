-- 11/1の日利データを簡易修正（差分更新）
-- より安全: データを削除せず差分だけ調整

-- === 現状確認 ===
SELECT '=== 現在の11/1データ ===' as info;
SELECT
    date,
    yield_rate as "現在のyield_rate",
    user_rate as "現在のuser_rate",
    -0.020 as "正しいyield_rate",
    -0.020 * (1 - 30.0/100) * 0.6 as "正しいuser_rate",
    user_rate - (-0.020 * (1 - 30.0/100) * 0.6) as "差分"
FROM daily_yield_log
WHERE date = '2025-11-01';

-- === 各ユーザーの差分を計算 ===
SELECT '=== ユーザー利益の差分 ===' as info;
WITH correct_rate AS (
    SELECT -0.020 * (1 - 30.0/100) * 0.6 as v_user_rate
),
current_rate AS (
    SELECT user_rate FROM daily_yield_log WHERE date = '2025-11-01'
)
SELECT
    udp.user_id,
    udp.daily_profit as "現在の利益",
    nm.nft_value * (SELECT v_user_rate FROM correct_rate) / 100 as "正しい利益",
    (nm.nft_value * (SELECT v_user_rate FROM correct_rate) / 100) - udp.daily_profit as "調整額"
FROM user_daily_profit udp
INNER JOIN (
    SELECT user_id, SUM(nft_value) as nft_value
    FROM nft_master
    WHERE status = 'active'
    GROUP BY user_id
) nm ON udp.user_id = nm.user_id
WHERE udp.date = '2025-11-01'
ORDER BY udp.user_id
LIMIT 10;

-- === 実行前の最終確認 ===
SELECT '⚠️ 以下の処理を実行しますか？' as warning;
SELECT
    '1. daily_yield_logの修正' as step,
    '-0.012% → -0.008%' as change;

SELECT
    '2. user_daily_profitの修正' as step,
    '各ユーザーの利益を再計算' as change;

SELECT
    '3. affiliate_cycleは自動調整されない' as warning,
    '紹介報酬に影響がある場合は reprocess-1101-yield.sql を使用' as note;

-- === ここから実行 ===
-- コメントアウトを外して実行してください

/*
-- 1. daily_yield_logを修正
UPDATE daily_yield_log
SET
    yield_rate = -0.020,
    user_rate = -0.020 * (1 - 30.0/100) * 0.6
WHERE date = '2025-11-01';

-- 2. user_daily_profitを修正
UPDATE user_daily_profit udp
SET daily_profit = nm.nft_value * (-0.020 * (1 - 30.0/100) * 0.6) / 100
FROM (
    SELECT user_id, SUM(nft_value) as nft_value
    FROM nft_master
    WHERE status = 'active'
    GROUP BY user_id
) nm
WHERE udp.user_id = nm.user_id
AND udp.date = '2025-11-01';

-- 3. 確認
SELECT '=== 修正完了 ===' as info;
SELECT
    date,
    yield_rate,
    user_rate
FROM daily_yield_log
WHERE date = '2025-11-01';

SELECT
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-11-01';
*/
