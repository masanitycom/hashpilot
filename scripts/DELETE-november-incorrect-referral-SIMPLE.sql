-- ========================================
-- 11月の誤配布データ削除スクリプト（シンプル版）
-- ========================================
--
-- 誤配布の詳細:
-- - レコード数: 2,937件
-- - 誤配布総額: $1,417.616
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
    SELECT COUNT(*), SUM(urp.profit_amount)
    INTO v_count, v_amount
    FROM user_referral_profit urp
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND NOT EXISTS (
        SELECT 1
        FROM user_daily_profit udp
        WHERE udp.user_id = urp.child_user_id
          AND udp.date = urp.date
      );

    RAISE NOTICE '=========================================';
    RAISE NOTICE '削除対象の確認';
    RAISE NOTICE '=========================================';
    RAISE NOTICE 'レコード数: %', v_count;
    RAISE NOTICE '金額: $%', v_amount;
    RAISE NOTICE '=========================================';

    IF v_count != 2937 THEN
        RAISE EXCEPTION '⚠️ レコード数が一致しません（期待: 2937, 実際: %）', v_count;
    END IF;
END $$;

-- ========================================
-- STEP 2: 削除対象を一時テーブルに保存
-- ========================================

CREATE TEMP TABLE temp_to_delete AS
SELECT
    urp.user_id,
    urp.date,
    urp.referral_level,
    urp.child_user_id,
    urp.profit_amount
FROM user_referral_profit urp
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
  AND NOT EXISTS (
    SELECT 1
    FROM user_daily_profit udp
    WHERE udp.user_id = urp.child_user_id
      AND udp.date = urp.date
  );

-- 一時テーブルの件数確認
DO $$
DECLARE
    v_temp_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_temp_count FROM temp_to_delete;
    RAISE NOTICE '一時テーブルに保存: %件', v_temp_count;
END $$;

-- ========================================
-- STEP 3: affiliate_cycleから誤配布額を減算
-- ========================================

WITH incorrect_by_parent AS (
    SELECT
        user_id as parent_user_id,
        SUM(profit_amount) as incorrect_amount
    FROM temp_to_delete
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
-- STEP 4: user_referral_profitから削除
-- ========================================

DELETE FROM user_referral_profit urp
WHERE EXISTS (
    SELECT 1
    FROM temp_to_delete ttd
    WHERE ttd.user_id = urp.user_id
      AND ttd.date = urp.date
      AND ttd.referral_level = urp.referral_level
      AND ttd.child_user_id = urp.child_user_id
);

DO $$
DECLARE
    v_deleted INTEGER;
BEGIN
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE '✅ user_referral_profit削除: %件', v_deleted;

    IF v_deleted != 2937 THEN
        RAISE EXCEPTION '⚠️ 削除数が一致しません（期待: 2937, 実際: %）', v_deleted;
    END IF;
END $$;

-- ========================================
-- STEP 5: 削除後の確認
-- ========================================

DO $$
DECLARE
    v_remaining INTEGER;
    v_total_referral NUMERIC;
    v_total_daily NUMERIC;
    v_ratio NUMERIC;
BEGIN
    -- 残っている誤配布レコード
    SELECT COUNT(*)
    INTO v_remaining
    FROM user_referral_profit urp
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND NOT EXISTS (
        SELECT 1
        FROM user_daily_profit udp
        WHERE udp.user_id = urp.child_user_id
          AND udp.date = urp.date
      );

    -- 11月の合計
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_total_referral
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_total_daily
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    IF v_total_daily > 0 THEN
        v_ratio := (v_total_referral / v_total_daily) * 100;
    ELSE
        v_ratio := 0;
    END IF;

    RAISE NOTICE '=========================================';
    RAISE NOTICE '削除後の確認';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '残っている誤配布: %件', v_remaining;
    RAISE NOTICE '';
    RAISE NOTICE '11月の個人利益: $%', v_total_daily;
    RAISE NOTICE '11月の紹介報酬: $%', v_total_referral;
    RAISE NOTICE '比率: %.2f%% (期待: 35%%)', v_ratio;
    RAISE NOTICE '=========================================';

    IF v_remaining > 0 THEN
        RAISE EXCEPTION '⚠️ まだ%件の誤配布が残っています', v_remaining;
    END IF;

    RAISE NOTICE '✅ すべての誤配布を削除しました';
END $$;

-- 一時テーブルを削除
DROP TABLE temp_to_delete;

-- ========================================
-- コミット
-- ========================================

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ 11月の誤配布データ削除完了';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '削除: 2,937件のレコード';
    RAISE NOTICE '金額: $1,417.616';
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ: V2システムに切り替え';
    RAISE NOTICE '=========================================';
END $$;
