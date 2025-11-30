-- ペガサス特例ユーザー対応: exclude_from_daily_profit フラグ追加
-- 実行環境: 本番Supabase
-- 目的: is_pegasus_exchange=TRUEでも日利を受け取れるユーザーを設定可能にする

-- =====================================
-- STEP 1: 新しいフラグ追加
-- =====================================

ALTER TABLE users
ADD COLUMN IF NOT EXISTS exclude_from_daily_profit BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN users.exclude_from_daily_profit IS '日利配布対象外フラグ。TRUEの場合は個人利益を受け取れない（ペガサス交換ユーザーなど）';

-- =====================================
-- STEP 2: 既存ペガサスユーザーをデフォルト設定
-- =====================================

-- 全ペガサスユーザーをまず対象外に設定
UPDATE users
SET exclude_from_daily_profit = TRUE
WHERE is_pegasus_exchange = TRUE;

-- =====================================
-- STEP 3: 特例3名を日利対象に設定
-- =====================================

UPDATE users
SET exclude_from_daily_profit = FALSE
WHERE email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
);

-- =====================================
-- STEP 4: 設定確認
-- =====================================

-- 特例3名の確認
SELECT
    user_id,
    email,
    is_pegasus_exchange,
    exclude_from_daily_profit,
    CASE
        WHEN exclude_from_daily_profit = FALSE THEN '日利対象（特例）'
        ELSE '日利対象外'
    END as status
FROM users
WHERE email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
);

-- 全ペガサスユーザーの確認
SELECT
    is_pegasus_exchange,
    exclude_from_daily_profit,
    COUNT(*) as user_count
FROM users
WHERE is_pegasus_exchange = TRUE
GROUP BY is_pegasus_exchange, exclude_from_daily_profit
ORDER BY exclude_from_daily_profit;

-- =====================================
-- STEP 5: RPC関数の修正が必要
-- =====================================

-- ⚠️ 注意: process_daily_yield_v2 関数を以下のように修正する必要があります
--
-- 修正前:
--   IF v_user_record.is_pegasus_exchange = TRUE THEN
--     CONTINUE;
--   END IF;
--
-- 修正後:
--   IF v_user_record.exclude_from_daily_profit = TRUE THEN
--     CONTINUE;
--   END IF;
--
-- この修正は別のスクリプトで実施します（FIX-rpc-exclude-from-daily-profit.sql）
