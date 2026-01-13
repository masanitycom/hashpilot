-- ========================================
-- 全問題の包括的修正スクリプト（最終版）
-- 実行日: 2026-01-13
-- ========================================
-- 修正内容:
-- 1. 59C23Cの不正NFT（日次処理で誤付与）を削除
-- 2. 59C23Cのaffiliate_cycle修正
-- 3. 1月の不正日次紹介報酬データ（4232件）を削除
-- 4. process_monthly_referral_profit関数のnft_sequence/nft_value追加
-- ========================================

-- ========================================
-- STEP 0: 修正前の状態確認
-- ========================================

SELECT '=== STEP 0: 修正前の状態確認 ===' as section;

-- 59C23CのNFT状態
SELECT '59C23C NFT:' as info, COUNT(*) as count FROM nft_master WHERE user_id = '59C23C';
SELECT '59C23C auto NFT:' as info, COUNT(*) as count FROM nft_master WHERE user_id = '59C23C' AND nft_type = 'auto';

-- 1月の日次紹介報酬データ
SELECT '1月日次紹介報酬:' as info, COUNT(*) as records, SUM(profit_amount) as total
FROM user_referral_profit WHERE date >= '2026-01-01';

-- ========================================
-- STEP 1: 59C23Cの不正データを修正
-- ========================================

SELECT '=== STEP 1: 59C23Cの不正NFT削除 ===' as section;

-- 1-1: 不正なNFT（1/9付与分）を削除
DELETE FROM nft_master
WHERE id = '073206f3-17f1-447c-bec3-03483a93a52e';

-- 1-2: 関連するpurchasesレコードを削除（存在する場合）
DELETE FROM purchases
WHERE user_id = '59C23C'
  AND is_auto_purchase = true
  AND created_at >= '2026-01-09'
  AND created_at < '2026-01-10';

-- 1-3: affiliate_cycleを修正
-- 紹介報酬累計: $2477.40
-- 正規の自動NFT: 1個（1/1付与分）
-- cum_usdt = 2477.40 - 1100 = 1377.40
UPDATE affiliate_cycle
SET
  cum_usdt = 1377.40,
  auto_nft_count = 1,
  total_nft_count = manual_nft_count + 1,
  phase = 'HOLD',       -- 1377.40 >= 1100 なのでHOLD
  updated_at = NOW()
WHERE user_id = '59C23C';

-- ========================================
-- STEP 2: 1月の不正日次紹介報酬データを削除
-- ========================================

SELECT '=== STEP 2: 1月の不正日次紹介報酬データ削除 ===' as section;

-- 削除前の確認
SELECT
  date,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2026-01-01'
GROUP BY date
ORDER BY date;

-- 2-1: 1月のuser_referral_profitデータを削除
-- （日次紹介報酬は廃止されており、これらは旧関数のバグで作成されたもの）
DELETE FROM user_referral_profit
WHERE date >= '2026-01-01';

-- ========================================
-- STEP 3: process_monthly_referral_profit関数を修正
-- （未使用だが念のため修正）
-- ========================================

SELECT '=== STEP 3: process_monthly_referral_profit関数修正 ===' as section;

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
    v_child_monthly_profit NUMERIC;
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
            UPDATE affiliate_cycle ac
            SET cum_usdt = cum_usdt - COALESCE((
                SELECT SUM(profit_amount) FROM monthly_referral_profit mrp
                WHERE mrp.user_id = ac.user_id AND mrp.year_month = p_year_month
            ), 0);
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
-- STEP 4: 確認クエリ
-- ========================================

SELECT '=== STEP 4: 修正後の確認 ===' as section;

-- 59C23Cの状態確認
SELECT '=== 59C23C NFT状態 ===' as check_type;
SELECT
  nm.user_id,
  nm.nft_type,
  nm.nft_sequence,
  nm.nft_value,
  nm.acquired_date
FROM nft_master nm
WHERE nm.user_id = '59C23C'
ORDER BY nm.acquired_date;

SELECT '=== 59C23C affiliate_cycle ===' as check_type;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count,
  phase
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 1月日次紹介報酬の確認
SELECT '=== 1月日次紹介報酬データ（削除後） ===' as check_type;
SELECT COUNT(*) as remaining_records FROM user_referral_profit WHERE date >= '2026-01-01';

-- 完了メッセージ
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '全修正完了';
  RAISE NOTICE '1. 59C23Cの不正NFT削除';
  RAISE NOTICE '2. 59C23Cのaffiliate_cycle修正';
  RAISE NOTICE '3. 1月の不正日次紹介報酬データ削除';
  RAISE NOTICE '4. process_monthly_referral_profit関数修正';
  RAISE NOTICE '========================================';
END $$;
