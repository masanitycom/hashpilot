-- ========================================
-- 全ユーザーの包括的データ修正スクリプト
-- 実行日: 2026-01-13
-- ========================================
-- このスクリプトは以下を修正します:
-- 1. 月末以外に作成された不正な自動NFTを削除
-- 2. auto_nft_countを実際のNFT数に同期
-- 3. cum_usdtをmonthly_referral_profitと同期
-- 4. total_nft_countを修正
-- 5. phaseを再計算
-- 6. 1月の不正日次紹介報酬データを削除
-- ========================================

-- ========================================
-- STEP 0: 修正前の状態確認
-- ========================================
SELECT '=== STEP 0: 修正前の問題件数 ===' as section;

-- 問題の総数を確認
SELECT 'auto_nft_count不一致ユーザー数' as issue_type, COUNT(*) as count
FROM (
  SELECT ac.user_id
  FROM affiliate_cycle ac
  LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
  GROUP BY ac.user_id, ac.auto_nft_count
  HAVING ac.auto_nft_count != COUNT(nm.id)
) t
UNION ALL
SELECT 'phase不整合ユーザー数' as issue_type, COUNT(*) as count
FROM affiliate_cycle
WHERE phase != CASE WHEN cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END
UNION ALL
SELECT '1月日次紹介報酬の影響ユーザー数' as issue_type, COUNT(DISTINCT user_id) as count
FROM user_referral_profit
WHERE date >= '2026-01-01'
UNION ALL
SELECT '月末以外に作成された自動NFT数' as issue_type, COUNT(*) as count
FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2026-01-01'
  AND EXTRACT(DAY FROM acquired_date) NOT IN (1, 28, 29, 30, 31);

-- ========================================
-- STEP 1: 月末以外に作成された不正な自動NFTを削除
-- （1/9など月末以外に誤って作成されたもの）
-- ========================================
SELECT '=== STEP 1: 不正な自動NFT削除 ===' as section;

-- 削除対象のNFTを表示
SELECT
  nm.user_id,
  nm.id as nft_id,
  nm.acquired_date,
  nm.nft_sequence
FROM nft_master nm
WHERE nm.nft_type = 'auto'
  AND nm.acquired_date >= '2026-01-01'
  AND EXTRACT(DAY FROM nm.acquired_date) NOT IN (1, 28, 29, 30, 31);

-- 不正な自動NFTを削除
DELETE FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2026-01-01'
  AND EXTRACT(DAY FROM acquired_date) NOT IN (1, 28, 29, 30, 31);

-- 関連するpurchasesレコードも削除
DELETE FROM purchases
WHERE is_auto_purchase = true
  AND created_at >= '2026-01-01'
  AND EXTRACT(DAY FROM created_at::date) NOT IN (1, 28, 29, 30, 31);

-- ========================================
-- STEP 2: auto_nft_countを実際のNFT数に同期
-- ========================================
SELECT '=== STEP 2: auto_nft_count同期 ===' as section;

-- 修正対象を表示
SELECT
  ac.user_id,
  ac.auto_nft_count as "現在のcount",
  COUNT(nm.id) as "実際のNFT数"
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
GROUP BY ac.user_id, ac.auto_nft_count
HAVING ac.auto_nft_count != COUNT(nm.id);

-- auto_nft_countを更新
UPDATE affiliate_cycle ac
SET
  auto_nft_count = COALESCE(nft_counts.actual_count, 0),
  updated_at = NOW()
FROM (
  SELECT
    ac2.user_id,
    COUNT(nm.id) as actual_count
  FROM affiliate_cycle ac2
  LEFT JOIN nft_master nm ON ac2.user_id = nm.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
  GROUP BY ac2.user_id
) nft_counts
WHERE ac.user_id = nft_counts.user_id
  AND ac.auto_nft_count != nft_counts.actual_count;

-- ========================================
-- STEP 3: total_nft_countを修正
-- ========================================
SELECT '=== STEP 3: total_nft_count修正 ===' as section;

UPDATE affiliate_cycle ac
SET
  total_nft_count = COALESCE(nft_counts.total, 0),
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    COUNT(*) as total
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nft_counts
WHERE ac.user_id = nft_counts.user_id
  AND ac.total_nft_count != nft_counts.total;

-- NFTがないユーザーのtotal_nft_countを0に
UPDATE affiliate_cycle
SET total_nft_count = 0, updated_at = NOW()
WHERE user_id NOT IN (SELECT DISTINCT user_id FROM nft_master WHERE buyback_date IS NULL)
  AND total_nft_count != 0;

-- ========================================
-- STEP 4: cum_usdtをmonthly_referral_profitと同期
-- cum_usdt = 月次紹介報酬累計 - (auto_nft_count × 1100)
-- ========================================
SELECT '=== STEP 4: cum_usdt同期 ===' as section;

-- 修正対象を表示
SELECT
  ac.user_id,
  ac.cum_usdt as "現在のcum_usdt",
  COALESCE(mrp.total, 0) as "月次紹介報酬累計",
  ac.auto_nft_count as "自動NFT数",
  COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100) as "期待されるcum_usdt"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(ac.cum_usdt - (COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100))) > 0.01
LIMIT 20;

-- cum_usdtを更新
UPDATE affiliate_cycle ac
SET
  cum_usdt = GREATEST(0, COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100)),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id;

-- 紹介報酬がないユーザーのcum_usdtを0に
UPDATE affiliate_cycle
SET cum_usdt = 0, updated_at = NOW()
WHERE user_id NOT IN (SELECT DISTINCT user_id FROM monthly_referral_profit)
  AND cum_usdt != 0
  AND auto_nft_count = 0;

-- ========================================
-- STEP 5: phaseを再計算
-- cum_usdt >= 1100 なら HOLD、< 1100 なら USDT
-- ========================================
SELECT '=== STEP 5: phase再計算 ===' as section;

UPDATE affiliate_cycle
SET
  phase = CASE WHEN cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END,
  updated_at = NOW()
WHERE phase != CASE WHEN cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END;

-- ========================================
-- STEP 6: 1月の不正日次紹介報酬データを削除
-- ========================================
SELECT '=== STEP 6: 1月日次紹介報酬削除 ===' as section;

-- 削除前に件数と金額を確認
SELECT
  '1月日次紹介報酬' as data_type,
  COUNT(*) as records,
  COUNT(DISTINCT user_id) as users,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2026-01-01';

-- 削除実行
DELETE FROM user_referral_profit
WHERE date >= '2026-01-01';

-- ========================================
-- STEP 7: 修正後の確認
-- ========================================
SELECT '=== STEP 7: 修正後の確認 ===' as section;

-- 問題の総数を再確認
SELECT 'auto_nft_count不一致ユーザー数' as issue_type, COUNT(*) as count
FROM (
  SELECT ac.user_id
  FROM affiliate_cycle ac
  LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
  GROUP BY ac.user_id, ac.auto_nft_count
  HAVING ac.auto_nft_count != COUNT(nm.id)
) t
UNION ALL
SELECT 'phase不整合ユーザー数' as issue_type, COUNT(*) as count
FROM affiliate_cycle
WHERE phase != CASE WHEN cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END
UNION ALL
SELECT '1月日次紹介報酬の影響ユーザー数' as issue_type, COUNT(DISTINCT user_id) as count
FROM user_referral_profit
WHERE date >= '2026-01-01'
UNION ALL
SELECT '月末以外に作成された自動NFT数' as issue_type, COUNT(*) as count
FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2026-01-01'
  AND EXTRACT(DAY FROM acquired_date) NOT IN (1, 28, 29, 30, 31);

-- ========================================
-- 完了メッセージ
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '全ユーザーの包括的データ修正完了';
  RAISE NOTICE '========================================';
  RAISE NOTICE '修正内容:';
  RAISE NOTICE '1. 月末以外に作成された不正な自動NFT削除';
  RAISE NOTICE '2. auto_nft_countを実際のNFT数に同期';
  RAISE NOTICE '3. total_nft_countを修正';
  RAISE NOTICE '4. cum_usdtをmonthly_referral_profitと同期';
  RAISE NOTICE '5. phaseを再計算';
  RAISE NOTICE '6. 1月の不正日次紹介報酬データ削除';
  RAISE NOTICE '========================================';
END $$;

-- ========================================
-- STEP 8: available_usdtの整合性確認と修正
-- ========================================
SELECT '=== STEP 8: available_usdt確認 ===' as section;

-- available_usdtの構成要素を確認
-- available_usdt = 日次利益累計 + USDTフェーズ紹介報酬 + (自動NFT × 1100) - 出金済み
SELECT
  ac.user_id,
  ac.available_usdt,
  COALESCE(ndp.total_profit, 0) as "日次利益累計",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  ac.auto_nft_count * 1100 as "自動NFT付与時加算",
  COALESCE(ac.withdrawn_referral_usdt, 0) as "出金済み紹介報酬",
  -- 1月の不正日次紹介報酬（もしavailable_usdtに加算されていた場合）
  COALESCE(jan_urp.jan_referral, 0) as "1月日次紹介報酬"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) ndp ON ac.user_id = ndp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM user_referral_profit
  WHERE date >= '2026-01-01'
  GROUP BY user_id
) jan_urp ON ac.user_id = jan_urp.user_id
WHERE jan_urp.jan_referral > 0
ORDER BY jan_urp.jan_referral DESC
LIMIT 20;

-- 注意: available_usdtは複雑な履歴を持つため、
-- 自動修正は危険。上記で確認後、必要に応じて手動修正を検討。

-- ========================================
-- STEP 9: process_monthly_referral_profit関数を修正
-- （未使用だが念のため修正）
-- ========================================
SELECT '=== STEP 9: process_monthly_referral_profit関数修正 ===' as section;

CREATE OR REPLACE FUNCTION process_monthly_referral_profit(
  p_year_month TEXT,
  p_is_test_mode BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(status TEXT, message TEXT, details JSONB)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
    v_level1_rate NUMERIC := 0.20;
    v_level2_rate NUMERIC := 0.10;
    v_level3_rate NUMERIC := 0.05;
    v_user_record RECORD;
    v_referral_record RECORD;
    v_referral_amount NUMERIC;
    v_total_referral NUMERIC := 0;
    v_referral_count INTEGER := 0;
    v_auto_nft_count INTEGER := 0;
    v_user_count INTEGER := 0;
    v_auto_nft_operation_start_date DATE;
    v_next_sequence INTEGER;
BEGIN
    IF p_year_month IS NULL OR p_year_month !~ '^\d{4}-\d{2}$' THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, '年月はYYYY-MM形式で指定してください'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    v_start_date := (p_year_month || '-01')::DATE;
    v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    v_auto_nft_operation_start_date := DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '14 days';

    IF EXISTS (SELECT 1 FROM monthly_referral_profit WHERE year_month = p_year_month) THEN
        IF NOT p_is_test_mode THEN
            RETURN QUERY SELECT 'ERROR'::TEXT, format('年月 %s の紹介報酬は既に計算済みです', p_year_month)::TEXT, NULL::JSONB;
            RETURN;
        ELSE
            DELETE FROM monthly_referral_profit WHERE year_month = p_year_month;
        END IF;
    END IF;

    FOR v_user_record IN
        SELECT DISTINCT u.user_id FROM users u
        WHERE u.has_approved_nft = true
            AND u.operation_start_date IS NOT NULL
            AND u.operation_start_date <= v_end_date
            AND EXISTS (SELECT 1 FROM users child WHERE child.referrer_user_id = u.user_id)
    LOOP
        -- Level 1
        FOR v_referral_record IN
            SELECT child.user_id as child_user_id, COALESCE(SUM(ndp.daily_profit), 0) as monthly_profit
            FROM users child
            LEFT JOIN nft_daily_profit ndp ON child.user_id = ndp.user_id AND ndp.date BETWEEN v_start_date AND v_end_date
            WHERE child.referrer_user_id = v_user_record.user_id
                AND child.has_approved_nft = true
                AND child.operation_start_date IS NOT NULL
                AND child.operation_start_date <= v_end_date
            GROUP BY child.user_id
            HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
        LOOP
            v_referral_amount := v_referral_record.monthly_profit * v_level1_rate;
            INSERT INTO monthly_referral_profit (user_id, year_month, referral_level, child_user_id, profit_amount, calculation_date)
            VALUES (v_user_record.user_id, p_year_month, 1, v_referral_record.child_user_id, v_referral_amount, CURRENT_DATE);
            v_total_referral := v_total_referral + v_referral_amount;
            v_referral_count := v_referral_count + 1;
        END LOOP;

        -- Level 2
        FOR v_referral_record IN
            SELECT grandchild.user_id as child_user_id, COALESCE(SUM(ndp.daily_profit), 0) as monthly_profit
            FROM users child
            INNER JOIN users grandchild ON child.user_id = grandchild.referrer_user_id
            LEFT JOIN nft_daily_profit ndp ON grandchild.user_id = ndp.user_id AND ndp.date BETWEEN v_start_date AND v_end_date
            WHERE child.referrer_user_id = v_user_record.user_id
                AND grandchild.has_approved_nft = true
                AND grandchild.operation_start_date IS NOT NULL
                AND grandchild.operation_start_date <= v_end_date
            GROUP BY grandchild.user_id
            HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
        LOOP
            v_referral_amount := v_referral_record.monthly_profit * v_level2_rate;
            INSERT INTO monthly_referral_profit (user_id, year_month, referral_level, child_user_id, profit_amount, calculation_date)
            VALUES (v_user_record.user_id, p_year_month, 2, v_referral_record.child_user_id, v_referral_amount, CURRENT_DATE);
            v_total_referral := v_total_referral + v_referral_amount;
            v_referral_count := v_referral_count + 1;
        END LOOP;

        -- Level 3
        FOR v_referral_record IN
            SELECT greatgrandchild.user_id as child_user_id, COALESCE(SUM(ndp.daily_profit), 0) as monthly_profit
            FROM users child
            INNER JOIN users grandchild ON child.user_id = grandchild.referrer_user_id
            INNER JOIN users greatgrandchild ON grandchild.user_id = greatgrandchild.referrer_user_id
            LEFT JOIN nft_daily_profit ndp ON greatgrandchild.user_id = ndp.user_id AND ndp.date BETWEEN v_start_date AND v_end_date
            WHERE child.referrer_user_id = v_user_record.user_id
                AND greatgrandchild.has_approved_nft = true
                AND greatgrandchild.operation_start_date IS NOT NULL
                AND greatgrandchild.operation_start_date <= v_end_date
            GROUP BY greatgrandchild.user_id
            HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
        LOOP
            v_referral_amount := v_referral_record.monthly_profit * v_level3_rate;
            INSERT INTO monthly_referral_profit (user_id, year_month, referral_level, child_user_id, profit_amount, calculation_date)
            VALUES (v_user_record.user_id, p_year_month, 3, v_referral_record.child_user_id, v_referral_amount, CURRENT_DATE);
            v_total_referral := v_total_referral + v_referral_amount;
            v_referral_count := v_referral_count + 1;
        END LOOP;

        v_user_count := v_user_count + 1;
    END LOOP;

    -- cum_usdtを更新
    UPDATE affiliate_cycle ac
    SET cum_usdt = cum_usdt + COALESCE((
        SELECT SUM(profit_amount) FROM monthly_referral_profit mrp
        WHERE mrp.user_id = ac.user_id AND mrp.year_month = p_year_month
    ), 0), updated_at = NOW()
    WHERE EXISTS (SELECT 1 FROM monthly_referral_profit mrp WHERE mrp.user_id = ac.user_id AND mrp.year_month = p_year_month);

    -- NFT自動付与（nft_sequenceとnft_valueを正しく設定）
    FOR v_user_record IN
        SELECT ac.user_id, ac.cum_usdt, ac.auto_nft_count FROM affiliate_cycle ac
        WHERE ac.cum_usdt >= 2200
            AND EXISTS (SELECT 1 FROM users u WHERE u.user_id = ac.user_id AND u.operation_start_date IS NOT NULL AND u.operation_start_date <= v_end_date)
    LOOP
        -- 次のnft_sequenceを計算
        SELECT COALESCE(MAX(nft_sequence), 0) + 1
        INTO v_next_sequence
        FROM nft_master
        WHERE user_id = v_user_record.user_id;

        -- NFT作成（nft_sequenceとnft_valueを設定）
        INSERT INTO nft_master (
            user_id,
            nft_sequence,
            nft_type,
            nft_value,
            acquired_date,
            buyback_date,
            operation_start_date,
            created_at
        ) VALUES (
            v_user_record.user_id,
            v_next_sequence,
            'auto',
            1000,
            v_end_date,
            NULL,
            v_auto_nft_operation_start_date,
            NOW()
        );

        INSERT INTO purchases (user_id, amount_usd, admin_approved, is_auto_purchase, created_at)
        VALUES (v_user_record.user_id, 1100, TRUE, TRUE, NOW());

        UPDATE affiliate_cycle
        SET cum_usdt = cum_usdt - 1100,
            available_usdt = available_usdt + 1100,
            auto_nft_count = auto_nft_count + 1,
            total_nft_count = total_nft_count + 1,
            phase = CASE WHEN (cum_usdt - 1100) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
            updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_auto_nft_count := v_auto_nft_count + 1;
    END LOOP;

    RETURN QUERY SELECT 'SUCCESS'::TEXT, format('月次紹介報酬計算完了 %s', p_year_month)::TEXT,
        jsonb_build_object('year_month', p_year_month, 'total_referral_profit', v_total_referral,
            'referral_count', v_referral_count, 'user_count', v_user_count, 'auto_nft_count', v_auto_nft_count,
            'auto_nft_operation_start_date', v_auto_nft_operation_start_date, 'is_test_mode', p_is_test_mode);
END;
$function$;

-- ========================================
-- 最終確認
-- ========================================
SELECT '=== 全修正完了 ===' as section;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '全ユーザーの包括的データ修正完了';
  RAISE NOTICE '========================================';
  RAISE NOTICE '修正内容:';
  RAISE NOTICE '1. 月末以外に作成された不正な自動NFT削除';
  RAISE NOTICE '2. auto_nft_countを実際のNFT数に同期';
  RAISE NOTICE '3. total_nft_countを修正';
  RAISE NOTICE '4. cum_usdtをmonthly_referral_profitと同期';
  RAISE NOTICE '5. phaseを再計算';
  RAISE NOTICE '6. 1月の不正日次紹介報酬データ削除';
  RAISE NOTICE '7. process_monthly_referral_profit関数修正';
  RAISE NOTICE '========================================';
END $$;
