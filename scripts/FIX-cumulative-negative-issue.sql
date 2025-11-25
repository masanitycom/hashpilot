-- ========================================
-- 累積マイナス問題の修正
-- ========================================
--
-- 問題: 過去に大きなマイナスの運用利益を設定したため、
--       累積がマイナスになり、配当が0になっている
--
-- 解決策: 累積をリセットして、正しい値から再スタート
-- ========================================

-- STEP 1: 現在の状況確認
SELECT
    '現在の累積状況' as section,
    date,
    total_profit_amount,
    cumulative_gross_profit,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    CASE
        WHEN cumulative_gross_profit < 0 THEN '❌ マイナス累積'
        WHEN daily_pnl <= 0 THEN '⚠️ 配当なし'
        ELSE '✅ 正常'
    END as status
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- STEP 2: 累積がマイナスになった日付を特定
SELECT
    '累積がマイナスになった日' as section,
    date,
    total_profit_amount,
    cumulative_gross_profit
FROM daily_yield_log_v2
WHERE cumulative_gross_profit < 0
ORDER BY date;

-- ========================================
-- 修正方法の選択肢
-- ========================================

-- 【選択肢A】全データをリセットして再計算（推奨）
-- ※ この方法は、過去のデータを全て削除して、累積を0から再スタートします

/*
-- A-1: バックアップを作成
CREATE TABLE daily_yield_log_v2_backup AS SELECT * FROM daily_yield_log_v2;
CREATE TABLE nft_daily_profit_backup AS SELECT * FROM nft_daily_profit;

-- A-2: 全データを削除
DELETE FROM stock_fund WHERE date >= '2025-11-01';
DELETE FROM user_referral_profit WHERE date >= '2025-11-01';
DELETE FROM nft_daily_profit WHERE date >= '2025-11-01';
DELETE FROM daily_yield_log_v2 WHERE date >= '2025-11-01';

-- A-3: 管理画面から日利を再設定
-- ※ この後、管理画面で各日の日利を再設定してください
*/

-- ========================================
-- 【選択肢B】特定の日付以降を再計算（部分修正）
-- ※ 累積がマイナスになった日以降のデータを削除して再計算
-- ========================================

-- B-1: 累積がマイナスになる直前の日付を確認
WITH last_positive AS (
    SELECT MAX(date) as last_positive_date
    FROM daily_yield_log_v2
    WHERE cumulative_gross_profit >= 0
)
SELECT
    '累積がマイナスになる直前' as section,
    lp.last_positive_date,
    dyl.cumulative_gross_profit,
    dyl.cumulative_net_profit
FROM last_positive lp
LEFT JOIN daily_yield_log_v2 dyl ON dyl.date = lp.last_positive_date;

-- B-2: その日以降のデータを削除（実行前に日付を確認してください）
/*
-- ⚠️ 警告: 以下のコマンドは実際のデータを削除します
-- 必ず日付を確認してから実行してください

DO $$
DECLARE
    v_reset_date DATE := '2025-11-05';  -- ← この日付以降を削除（要調整）
BEGIN
    DELETE FROM stock_fund WHERE date >= v_reset_date;
    DELETE FROM user_referral_profit WHERE date >= v_reset_date;
    DELETE FROM nft_daily_profit WHERE date >= v_reset_date;
    DELETE FROM daily_yield_log_v2 WHERE date >= v_reset_date;

    RAISE NOTICE '✅ %以降のデータを削除しました', v_reset_date;
END $$;
*/

-- ========================================
-- 【選択肢C】累積をオフセット調整（応急処置）
-- ※ 既存の累積に調整値を加算して、プラスにする
-- ========================================

/*
-- C-1: 必要なオフセット値を計算
WITH min_cumulative AS (
    SELECT MIN(cumulative_gross_profit) as min_value
    FROM daily_yield_log_v2
)
SELECT
    '必要なオフセット' as section,
    min_value,
    ABS(min_value) + 1000 as suggested_offset  -- マイナスを吸収 + 余裕
FROM min_cumulative;

-- C-2: オフセットを適用（実行前にoffset値を確認）
DO $$
DECLARE
    v_offset NUMERIC := 10000;  -- ← 上記で計算したオフセット値を設定
BEGIN
    UPDATE daily_yield_log_v2
    SET
        cumulative_gross_profit = cumulative_gross_profit + v_offset,
        cumulative_net_profit = cumulative_net_profit + (v_offset * 0.7),  -- 30%手数料を考慮
        cumulative_fee = (cumulative_gross_profit + v_offset) * 0.3
    WHERE cumulative_gross_profit < 0;

    RAISE NOTICE '✅ オフセット調整完了';
END $$;
*/

-- ========================================
-- STEP 3: 修正後の確認
-- ========================================

-- 修正後に実行して、累積が正常になったか確認
SELECT
    '修正後の確認' as section,
    date,
    total_profit_amount,
    cumulative_gross_profit,
    cumulative_net_profit,
    daily_pnl,
    CASE
        WHEN cumulative_gross_profit < 0 THEN '❌ まだマイナス'
        WHEN daily_pnl > 0 THEN '✅ 配当あり'
        ELSE '⚠️ 配当なし（マイナス日利）'
    END as status
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- ========================================
-- 推奨される修正手順
-- ========================================
/*
1. まず現在の状況を確認（STEP 1を実行）
2. バックアップを作成（選択肢A-1）
3. データをリセット（選択肢A-2）
4. 管理画面で日利を再設定
   - 正しい運用利益の値を設定
   - マイナスの日は実際の損失額を設定
5. 修正後の確認（STEP 3を実行）
6. ユーザーダッシュボードで表示を確認

※ 注意: マイナスの日利は配当0になりますが、
  累積計算は正しく行われます。
*/

-- ========================================
-- 完了メッセージ
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '累積マイナス問題の修正スクリプト';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '';
    RAISE NOTICE '現在の問題:';
    RAISE NOTICE '  - 累積がマイナスのため配当が0';
    RAISE NOTICE '  - nft_daily_profitにレコードが作成されない';
    RAISE NOTICE '  - ユーザーダッシュボードに表示されない';
    RAISE NOTICE '';
    RAISE NOTICE '修正方法:';
    RAISE NOTICE '  【推奨】選択肢A: 全データリセット';
    RAISE NOTICE '  選択肢B: 部分的に再計算';
    RAISE NOTICE '  選択肢C: オフセット調整（応急処置）';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ 実行前に必ずバックアップを取ってください';
    RAISE NOTICE '===========================================';
END $$;
