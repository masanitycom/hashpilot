-- 11/1の日利処理を正しい値で再実行するスクリプト
-- より安全な方法: RPC関数を使って再計算

-- ⚠️ 注意: この処理により以下がリセット・再計算されます
-- 1. daily_yields (日利率)
-- 2. user_daily_profit (個人利益)
-- 3. user_referral_profit (紹介報酬)
-- 4. affiliate_cycle (サイクル計算)
-- 5. 自動NFT付与（該当する場合）
-- 6. 月次出金処理（該当する場合）

-- 注意: daily_yield_logテーブルを使用（daily_yieldsではない）

-- === STEP 1: 現在のデータをバックアップ（確認用） ===
CREATE TEMP TABLE backup_daily_yield_log AS
SELECT * FROM daily_yield_log WHERE date = '2025-11-01';

CREATE TEMP TABLE backup_user_daily_profit AS
SELECT * FROM user_daily_profit WHERE date = '2025-11-01';

CREATE TEMP TABLE backup_user_referral_profit AS
SELECT * FROM user_referral_profit WHERE date = '2025-11-01';

-- バックアップ確認
SELECT '=== BACKUP: daily_yield_log ===' as info;
SELECT * FROM backup_daily_yield_log;

SELECT '=== BACKUP: user_daily_profit (合計) ===' as info;
SELECT COUNT(*) as count, SUM(profit_amount) as total FROM backup_user_daily_profit;

SELECT '=== BACKUP: user_referral_profit (合計) ===' as info;
SELECT COUNT(*) as count, SUM(reward_amount) as total FROM backup_user_referral_profit;

-- === STEP 2: 11/1のデータを削除 ===
DELETE FROM user_referral_profit WHERE date = '2025-11-01';
DELETE FROM user_daily_profit WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-01';

-- === STEP 3: RPC関数で再計算 ===
-- 正しい値: -0.02% (パーセント値のまま)
SELECT * FROM process_daily_yield_with_cycles(
    p_date := '2025-11-01',
    p_yield_rate := -0.02,
    p_margin_rate := 30.0,
    p_is_test_mode := FALSE,
    p_skip_validation := FALSE
);

-- === STEP 4: 修正後のデータを確認 ===
SELECT '=== AFTER FIX: daily_yield_log ===' as info;
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate
FROM daily_yield_log
WHERE date = '2025-11-01';

SELECT '=== AFTER FIX: user_daily_profit (合計) ===' as info;
SELECT
    COUNT(*) as user_count,
    SUM(profit_amount) as total_profit
FROM user_daily_profit
WHERE date = '2025-11-01';

SELECT '=== AFTER FIX: user_referral_profit (合計) ===' as info;
SELECT
    COUNT(*) as reward_count,
    SUM(reward_amount) as total_rewards
FROM user_referral_profit
WHERE date = '2025-11-01';

-- === STEP 5: 差分を確認 ===
SELECT '=== 差分確認 ===' as info;
SELECT
    'user_daily_profit' as table_name,
    (SELECT SUM(profit_amount) FROM user_daily_profit WHERE date = '2025-11-01') -
    (SELECT SUM(profit_amount) FROM backup_user_daily_profit) as difference;

-- === 注意事項 ===
-- ✅ このスクリプトは11/1のデータのみを再計算します
-- ✅ affiliate_cycleの累積額も正しく更新されます
-- ⚠️ 実行前に必ずバックアップを確認してください
-- ⚠️ 本番環境では慎重に実行してください
