-- ===============================================
-- ⚠️ 運用開始日未設定ユーザーの誤配布日利を削除
-- ===============================================
--
-- 警告:
--   このスクリプトは過去の誤配布データを削除します。
--   実行前に必ずバックアップを取ってください！
--
-- 影響:
--   - user_daily_profit: 誤配布された日利レコードを削除
--   - user_referral_profit: 誤配布された紹介報酬レコードを削除
--   - affiliate_cycle: available_usdtとcum_usdtから誤配布額を減算
--
-- 実行前の確認:
--   CHECK-incorrect-daily-profit-details.sql を先に実行して影響範囲を確認
--
-- 実行日: 2025-11-13
-- ===============================================

-- ⚠️ トランザクション開始（問題があればロールバック可能）
BEGIN;

-- ? STEP 1: バックアップテーブル作成（念のため）
CREATE TABLE IF NOT EXISTS user_daily_profit_backup_20251113 AS
SELECT * FROM user_daily_profit
WHERE user_id IN (
    SELECT user_id FROM users WHERE operation_start_date IS NULL
);

CREATE TABLE IF NOT EXISTS user_referral_profit_backup_20251113 AS
SELECT urp.*
FROM user_referral_profit urp
INNER JOIN users u ON urp.child_user_id = u.user_id
WHERE u.operation_start_date IS NULL;

-- ? STEP 2: affiliate_cycleから誤配布額を減算

-- 2-1. 個人利益の誤配布額を計算
WITH incorrect_personal_profit AS (
    SELECT
        udp.user_id,
        COALESCE(SUM(udp.daily_profit), 0) as total_incorrect
    FROM user_daily_profit udp
    INNER JOIN users u ON udp.user_id = u.user_id
    WHERE u.operation_start_date IS NULL
    GROUP BY udp.user_id
)
UPDATE affiliate_cycle ac
SET
    available_usdt = available_usdt - ipp.total_incorrect,
    updated_at = NOW()
FROM incorrect_personal_profit ipp
WHERE ac.user_id = ipp.user_id;

-- 2-2. 紹介報酬の誤配布額を計算（紹介者のcum_usdtから減算）
WITH incorrect_referral_profit AS (
    SELECT
        urp.user_id as referrer_id,
        COALESCE(SUM(urp.profit_amount), 0) as total_incorrect
    FROM user_referral_profit urp
    INNER JOIN users u ON urp.child_user_id = u.user_id
    WHERE u.operation_start_date IS NULL
    GROUP BY urp.user_id
)
UPDATE affiliate_cycle ac
SET
    cum_usdt = cum_usdt - irp.total_incorrect,
    updated_at = NOW()
FROM incorrect_referral_profit irp
WHERE ac.user_id = irp.referrer_id;

-- ? STEP 3: 誤配布された日利レコードを削除
DELETE FROM user_daily_profit
WHERE user_id IN (
    SELECT user_id FROM users WHERE operation_start_date IS NULL
);

-- ? STEP 4: 誤配布された紹介報酬レコードを削除
DELETE FROM user_referral_profit
WHERE child_user_id IN (
    SELECT user_id FROM users WHERE operation_start_date IS NULL
);

-- ? STEP 5: 削除結果の確認
SELECT
    '削除完了' as status,
    (SELECT COUNT(*) FROM user_daily_profit_backup_20251113) as backed_up_daily_profit_records,
    (SELECT COUNT(*) FROM user_referral_profit_backup_20251113) as backed_up_referral_records,
    (SELECT COUNT(*) FROM user_daily_profit WHERE user_id IN (SELECT user_id FROM users WHERE operation_start_date IS NULL)) as remaining_daily_profit_records,
    (SELECT COUNT(*) FROM user_referral_profit WHERE child_user_id IN (SELECT user_id FROM users WHERE operation_start_date IS NULL)) as remaining_referral_records;

-- ⚠️ ここで確認してから以下のいずれかを実行:
-- COMMIT;   -- 削除を確定
-- ROLLBACK; -- 削除を取り消し
