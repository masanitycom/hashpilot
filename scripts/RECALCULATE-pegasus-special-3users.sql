-- ペガサス特例3名の日利再計算スクリプト
-- 実行環境: 本番Supabase
-- 対象: balance.p.p.p.p.1060@gmail.com, akihiro.y.grant@gmail.com, feel.me.yurie@gmail.com
-- 期間: 2025-11-01 以降の全日利

-- =====================================
-- 前提条件の確認
-- =====================================

-- 1. 3名のユーザーIDとNFT情報を確認
SELECT
    u.user_id,
    u.email,
    u.is_pegasus_exchange,
    u.exclude_from_daily_profit,
    u.operation_start_date,
    COUNT(nm.id) as nft_count
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
GROUP BY u.user_id, u.email, u.is_pegasus_exchange, u.exclude_from_daily_profit, u.operation_start_date;

-- 2. 2025-11-01以降の日利設定履歴を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    ROUND((1000.0 * (yield_rate / 100.0)) * (1.0 - margin_rate) * 0.6, 3) as profit_per_nft
FROM daily_yield_log
WHERE date >= '2025-11-01'
ORDER BY date ASC;

-- =====================================
-- 実行手順
-- =====================================

-- ⚠️ 注意: 以下のステップを順番に実行してください
--
-- STEP 1: exclude_from_daily_profit フラグ設定
--   → scripts/ADD-exclude-from-daily-profit-flag.sql を実行
--
-- STEP 2: RPC関数の更新
--   → scripts/FIX-rpc-exclude-from-daily-profit.sql を実行
--
-- STEP 3: 日利の再計算（以下のSQLを1日ずつ実行）
--   → 管理画面 (/admin/yield) から各日付の日利を削除＆再設定
--   → または以下のRPC関数を直接呼び出し

-- =====================================
-- 再計算用RPC呼び出し例
-- =====================================

-- ⚠️ 以下は例です。実際の日利率・マージン率は daily_yield_log から取得してください

-- 例: 2025-11-01 の日利を再計算
-- SELECT * FROM process_daily_yield_with_cycles(
--   p_date := '2025-11-01',
--   p_yield_rate := 0.00952,  -- daily_yield_log.yield_rate / 100
--   p_margin_rate := 0.3,
--   p_is_test_mode := false,
--   p_skip_validation := false
-- );

-- =====================================
-- 自動再計算スクリプト（参考）
-- =====================================

-- ⚠️ このスクリプトは参考用です。実際には管理画面から1日ずつ実行することを推奨します
--
-- DO $$
-- DECLARE
--   r RECORD;
-- BEGIN
--   FOR r IN
--     SELECT
--       date,
--       yield_rate / 100.0 as yield_decimal,
--       margin_rate
--     FROM daily_yield_log
--     WHERE date >= '2025-11-01'
--     ORDER BY date ASC
--   LOOP
--     RAISE NOTICE '再計算中: %', r.date;
--
--     PERFORM process_daily_yield_with_cycles(
--       p_date := r.date,
--       p_yield_rate := r.yield_decimal,
--       p_margin_rate := r.margin_rate,
--       p_is_test_mode := false,
--       p_skip_validation := false
--     );
--   END LOOP;
-- END $$;

-- =====================================
-- 検証
-- =====================================

-- 再計算後、3名の日利が正しく付与されたか確認
SELECT
    u.user_id,
    u.email,
    COUNT(ndp.id) as profit_record_count,
    COALESCE(SUM(ndp.daily_profit), 0) as total_personal_profit,
    ac.available_usdt,
    ac.cum_usdt
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
GROUP BY u.user_id, u.email, ac.available_usdt, ac.cum_usdt
ORDER BY u.email;
