-- ========================================
-- 11月の紹介報酬データを完全削除
-- ========================================
--
-- 誤配布データ:
-- - レコード数: 14,975件
-- - 誤配布総額: $11,940.131
-- - 親ユーザー: 268名
-- - 子ユーザー: 300名
--
-- 処理内容:
-- 1. affiliate_cycleから誤配布額を減算
-- 2. user_referral_profitから全レコードを削除
--
-- ⚠️ 警告: この操作は取り消せません
-- 必ずバックアップを取ってから実行してください
-- ========================================

BEGIN;

-- ========================================
-- STEP 1: 削除対象の確認
-- ========================================

DO $$
DECLARE
    v_count INTEGER;
    v_amount NUMERIC;
BEGIN
    SELECT COUNT(*), SUM(profit_amount)
    INTO v_count, v_amount
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    RAISE NOTICE '========================================';
    RAISE NOTICE '削除対象の確認';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'レコード数: %', v_count;
    RAISE NOTICE '金額: $%', v_amount;
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- STEP 2: affiliate_cycleから誤配布額を減算
-- ========================================

WITH incorrect_by_parent AS (
    SELECT
        user_id as parent_user_id,
        SUM(profit_amount) as incorrect_amount
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET
    cum_usdt = cum_usdt - ibp.incorrect_amount,
    available_usdt = available_usdt - ibp.incorrect_amount,
    updated_at = NOW()
FROM incorrect_by_parent ibp
WHERE ac.user_id = ibp.parent_user_id;

DO $$
DECLARE
    v_updated INTEGER;
BEGIN
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RAISE NOTICE '✅ affiliate_cycle更新: %名', v_updated;
END $$;

-- ========================================
-- STEP 3: user_referral_profitから全削除
-- ========================================

DELETE FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

DO $$
DECLARE
    v_deleted INTEGER;
BEGIN
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE '✅ user_referral_profit削除: %件', v_deleted;
END $$;

-- ========================================
-- STEP 4: 削除後の確認
-- ========================================

DO $$
DECLARE
    v_remaining INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_remaining
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    RAISE NOTICE '========================================';
    RAISE NOTICE '削除後の確認';
    RAISE NOTICE '========================================';
    RAISE NOTICE '残っているレコード: %件', v_remaining;
    RAISE NOTICE '========================================';

    IF v_remaining > 0 THEN
        RAISE EXCEPTION '⚠️ まだ%件のレコードが残っています', v_remaining;
    END IF;

    RAISE NOTICE '✅ すべての紹介報酬レコードを削除しました';
END $$;

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ 11月の紹介報酬データ削除完了';
    RAISE NOTICE '========================================';
    RAISE NOTICE '次のステップ: 月末計算で正しく再計算';
    RAISE NOTICE 'SELECT * FROM process_monthly_referral_reward(2025, 11);';
    RAISE NOTICE '========================================';
END $$;
