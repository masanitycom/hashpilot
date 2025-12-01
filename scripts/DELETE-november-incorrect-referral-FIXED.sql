-- ========================================
-- 11月の誤配布データ削除スクリプト（修正版）
-- ========================================
--
-- 誤配布の詳細:
-- - レコード数: 2,937件
-- - 誤配布総額: $1,417.616
-- - 影響を受けた親ユーザー: 75名
-- - 影響を受けた子ユーザー: 65名
--
-- 処理内容:
-- 1. affiliate_cycleから誤配布額を減算
-- 2. user_referral_profitから誤配布レコードを削除
--
-- ⚠️ 警告: この操作は取り消せません
-- 必ずバックアップを取ってから実行してください
-- ========================================

BEGIN;

-- ========================================
-- STEP 1: 影響を受けるユーザーの確認（実行前チェック）
-- ========================================

DO $$
DECLARE
    v_incorrect_records INTEGER;
    v_incorrect_amount NUMERIC;
    v_affected_parents INTEGER;
    v_affected_children INTEGER;
BEGIN
    -- 誤配布レコードの集計
    WITH child_daily AS (
        SELECT
            urp.user_id as parent_user_id,
            urp.child_user_id,
            urp.profit_amount as recorded_profit,
            COALESCE(udp.daily_profit, 0) as child_daily_profit
        FROM user_referral_profit urp
        LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
        WHERE urp.date >= '2025-11-01'
          AND urp.date <= '2025-11-30'
          AND COALESCE(udp.daily_profit, 0) = 0
          AND urp.profit_amount > 0
    )
    SELECT
        COUNT(*),
        SUM(recorded_profit),
        COUNT(DISTINCT parent_user_id),
        COUNT(DISTINCT child_user_id)
    INTO v_incorrect_records, v_incorrect_amount, v_affected_parents, v_affected_children
    FROM child_daily;

    RAISE NOTICE '=========================================';
    RAISE NOTICE '削除対象の確認';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '誤配布レコード数: %', v_incorrect_records;
    RAISE NOTICE '誤配布総額: $%', v_incorrect_amount;
    RAISE NOTICE '影響を受けた親ユーザー: %名', v_affected_parents;
    RAISE NOTICE '影響を受けた子ユーザー: %名', v_affected_children;
    RAISE NOTICE '=========================================';

    -- 期待値との一致確認
    IF v_incorrect_records != 2937 THEN
        RAISE EXCEPTION '⚠️ レコード数が一致しません（期待: 2937, 実際: %）', v_incorrect_records;
    END IF;

    IF ABS(v_incorrect_amount - 1417.616) > 0.01 THEN
        RAISE EXCEPTION '⚠️ 金額が一致しません（期待: $1417.616, 実際: $%）', v_incorrect_amount;
    END IF;

    RAISE NOTICE '✅ 削除対象の確認完了';
END $$;

-- ========================================
-- STEP 2: affiliate_cycleから誤配布額を減算
-- ========================================

-- 各親ユーザーごとに誤配布額を集計
WITH incorrect_by_parent AS (
    SELECT
        urp.user_id as parent_user_id,
        SUM(urp.profit_amount) as incorrect_amount
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND COALESCE(udp.daily_profit, 0) = 0
      AND urp.profit_amount > 0
    GROUP BY urp.user_id
)
UPDATE affiliate_cycle ac
SET
    cum_usdt = cum_usdt - ibp.incorrect_amount,
    available_usdt = available_usdt - ibp.incorrect_amount,
    updated_at = NOW()
FROM incorrect_by_parent ibp
WHERE ac.user_id = ibp.parent_user_id;

-- 更新されたレコード数を表示
DO $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ affiliate_cycle更新完了: %名のユーザー', v_updated_count;
END $$;

-- ========================================
-- STEP 3: user_referral_profitから誤配布レコードを削除（修正版）
-- ========================================

-- 削除対象のレコードIDを一時テーブルに保存
CREATE TEMP TABLE temp_delete_ids AS
SELECT urp.user_id, urp.date, urp.referral_level, urp.child_user_id
FROM user_referral_profit urp
LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
WHERE urp.date >= '2025-11-01'
  AND urp.date <= '2025-11-30'
  AND COALESCE(udp.daily_profit, 0) = 0
  AND urp.profit_amount > 0;

-- 削除対象の件数を確認
DO $$
DECLARE
    v_to_delete INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_to_delete FROM temp_delete_ids;
    RAISE NOTICE '削除対象レコード: %件', v_to_delete;

    IF v_to_delete != 2937 THEN
        RAISE EXCEPTION '⚠️ 削除対象が一致しません（期待: 2937, 実際: %）', v_to_delete;
    END IF;
END $$;

-- 実際に削除
DELETE FROM user_referral_profit urp
USING temp_delete_ids tdi
WHERE urp.user_id = tdi.user_id
  AND urp.date = tdi.date
  AND urp.referral_level = tdi.referral_level
  AND urp.child_user_id = tdi.child_user_id;

-- 削除されたレコード数を表示
DO $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE '✅ user_referral_profit削除完了: %件のレコード', v_deleted_count;

    IF v_deleted_count != 2937 THEN
        RAISE EXCEPTION '⚠️ 削除レコード数が一致しません（期待: 2937, 実際: %）', v_deleted_count;
    END IF;
END $$;

-- 一時テーブルを削除
DROP TABLE temp_delete_ids;

-- ========================================
-- STEP 4: 削除後の確認
-- ========================================

DO $$
DECLARE
    v_remaining_incorrect INTEGER;
    v_total_referral NUMERIC;
    v_total_daily NUMERIC;
BEGIN
    -- 誤配布レコードが残っていないか確認
    SELECT COUNT(*)
    INTO v_remaining_incorrect
    FROM user_referral_profit urp
    LEFT JOIN user_daily_profit udp ON urp.child_user_id = udp.user_id AND urp.date = udp.date
    WHERE urp.date >= '2025-11-01'
      AND urp.date <= '2025-11-30'
      AND COALESCE(udp.daily_profit, 0) = 0
      AND urp.profit_amount > 0;

    -- 11月の紹介報酬と個人利益の合計
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_total_referral
    FROM user_referral_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_total_daily
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30';

    RAISE NOTICE '=========================================';
    RAISE NOTICE '削除後の確認';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '残っている誤配布レコード: %件', v_remaining_incorrect;
    RAISE NOTICE '';
    RAISE NOTICE '11月の紹介報酬合計: $%', v_total_referral;
    RAISE NOTICE '11月の個人利益合計: $%', v_total_daily;
    RAISE NOTICE '期待される紹介報酬（35%%）: $%', v_total_daily * 0.35;
    RAISE NOTICE '比率: %.2f%%', (v_total_referral / NULLIF(v_total_daily, 0)) * 100;
    RAISE NOTICE '=========================================';

    IF v_remaining_incorrect > 0 THEN
        RAISE EXCEPTION '⚠️ まだ誤配布レコードが%件残っています', v_remaining_incorrect;
    END IF;

    RAISE NOTICE '✅ すべての誤配布レコードが削除されました';
END $$;

-- ========================================
-- STEP 5: コミット
-- ========================================

COMMIT;

-- 最終メッセージ
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ 11月の誤配布データ削除完了';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '削除されたレコード: 2,937件';
    RAISE NOTICE '削除された金額: $1,417.616';
    RAISE NOTICE '影響を受けたユーザー: 75名';
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '1. ユーザーのダッシュボードで金額を確認';
    RAISE NOTICE '2. V2システムに切り替え';
    RAISE NOTICE '=========================================';
END $$;
