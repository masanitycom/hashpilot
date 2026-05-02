-- ========================================
-- 9A3A16のNFTカウント修正 + check_monthly_integrity改良
-- ========================================
-- 目的:
--   1. 9A3A16のtotal_nft_count = -167 を 0 に修正
--      （167個全て4/17にbuyback済み、buyback処理時のバグでマイナス値になった）
--   2. check_monthly_integrity の Check 3 を改良
--      HOLDフェーズロックとAuto-NFTロックを考慮した計算式に変更
-- ========================================

-- ========== STEP 1: 9A3A16のNFTカウント修正 ==========

-- 修正前の状態確認
SELECT
  user_id,
  total_nft_count,
  manual_nft_count,
  auto_nft_count
FROM affiliate_cycle
WHERE user_id = '9A3A16';

-- 修正実行
UPDATE affiliate_cycle
SET
  total_nft_count = 0,
  manual_nft_count = 0,
  auto_nft_count = 0,
  updated_at = NOW()
WHERE user_id = '9A3A16';

-- 修正後の確認
SELECT
  ac.user_id,
  ac.total_nft_count as cycle_total,
  ac.manual_nft_count as cycle_manual,
  ac.auto_nft_count as cycle_auto,
  COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_active,
  COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NOT NULL) as actual_buyback
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
WHERE ac.user_id = '9A3A16'
GROUP BY ac.user_id, ac.total_nft_count, ac.manual_nft_count, ac.auto_nft_count;
-- → cycle_total = 0, actual_active = 0 になっているはず

-- ========== STEP 2: check_monthly_integrity 関数を改良 ==========
-- HOLDフェーズロックとAuto-NFTロックを考慮するように変更

CREATE OR REPLACE FUNCTION check_monthly_integrity(
    p_year INTEGER,
    p_month INTEGER
)
RETURNS TABLE(
    check_name TEXT,
    check_result TEXT,
    affected_count INTEGER,
    details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_target_month DATE;
    v_year_month TEXT;
    v_count INTEGER;
    v_details JSONB;
BEGIN
    v_target_month := make_date(p_year, p_month, 1);
    v_year_month := format('%s-%s', p_year, LPAD(p_month::TEXT, 2, '0'));

    -- ========================================
    -- CHECK 1: 出金レコード漏れ
    -- ========================================
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'user_id', sub.user_id,
        'email', sub.email,
        'available_usdt', sub.available_usdt
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT ac.user_id, u.email, ac.available_usdt
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
        WHERE ac.available_usdt > 0
          AND u.is_active_investor = true
          AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM monthly_withdrawals mw
              WHERE mw.user_id = ac.user_id
                AND mw.withdrawal_month = v_target_month
          )
    ) sub;

    check_name := '出金レコード漏れ';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;

    -- ========================================
    -- CHECK 2: 紹介報酬漏れ(L1)
    -- ========================================
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'parent_id', sub.parent_id,
        'child_id', sub.child_id,
        'expected_amount', sub.expected_amount
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT
            u.user_id as parent_id,
            child.user_id as child_id,
            ROUND(SUM(ndp.daily_profit) * 0.20, 2) as expected_amount
        FROM users u
        JOIN users child ON child.referrer_user_id = u.user_id
        JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id
        WHERE ndp.date >= v_target_month
          AND ndp.date < (v_target_month + INTERVAL '1 month')
          AND u.has_approved_nft = true
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= (v_target_month + INTERVAL '1 month' - INTERVAL '1 day')::DATE
          AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
          AND child.has_approved_nft = true
          AND child.operation_start_date IS NOT NULL
          AND child.operation_start_date <= (v_target_month + INTERVAL '1 month' - INTERVAL '1 day')::DATE
        GROUP BY u.user_id, child.user_id
        HAVING SUM(ndp.daily_profit) > 0
          AND NOT EXISTS (
              SELECT 1 FROM monthly_referral_profit mrp
              WHERE mrp.user_id = u.user_id
                AND mrp.child_user_id = child.user_id
                AND mrp.year_month = v_year_month
                AND mrp.referral_level = 1
          )
    ) sub;

    check_name := '紹介報酬漏れ(L1)';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;

    -- ========================================
    -- CHECK 3: available_usdt整合性（改良版）
    -- HOLDロック・Auto-NFTロックを考慮した計算式
    --
    -- 計算式:
    --   referral_available = total_referral
    --                        - (auto_nft_count × $1100)         ← Auto-NFT consumed
    --                        - GREATEST(0, cum_usdt - 1100)     ← HOLD lock
    --   expected = profit + referral_available - withdrawn
    -- ========================================
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'user_id', sub.user_id,
        'expected', sub.expected_available,
        'actual', sub.actual_available,
        'difference', sub.difference,
        'auto_nft_lock', sub.auto_nft_lock,
        'hold_lock', sub.hold_lock
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT
            ac.user_id,
            -- 各ロック金額
            (ac.auto_nft_count * 1100) as auto_nft_lock,
            GREATEST(0, ac.cum_usdt - 1100) as hold_lock,
            -- 計算式
            ROUND((
                COALESCE(e.total_profit, 0)
                + COALESCE(r.total_referral, 0)
                - COALESCE(w.total_withdrawn, 0)
                - (ac.auto_nft_count * 1100)
                - GREATEST(0, ac.cum_usdt - 1100)
            )::numeric, 2) as expected_available,
            ROUND(ac.available_usdt::numeric, 2) as actual_available,
            ROUND((
                ac.available_usdt - (
                    COALESCE(e.total_profit, 0)
                    + COALESCE(r.total_referral, 0)
                    - COALESCE(w.total_withdrawn, 0)
                    - (ac.auto_nft_count * 1100)
                    - GREATEST(0, ac.cum_usdt - 1100)
                )
            )::numeric, 2) as difference
        FROM affiliate_cycle ac
        LEFT JOIN (
            SELECT user_id, SUM(daily_profit) as total_profit
            FROM nft_daily_profit GROUP BY user_id
        ) e ON ac.user_id = e.user_id
        LEFT JOIN (
            SELECT user_id, SUM(profit_amount) as total_referral
            FROM monthly_referral_profit GROUP BY user_id
        ) r ON ac.user_id = r.user_id
        LEFT JOIN (
            SELECT user_id, SUM(total_amount) as total_withdrawn
            FROM monthly_withdrawals mw2 WHERE mw2.status = 'completed'
            GROUP BY user_id
        ) w ON ac.user_id = w.user_id
        WHERE ac.available_usdt > 0
          AND ABS(
              ac.available_usdt - (
                  COALESCE(e.total_profit, 0)
                  + COALESCE(r.total_referral, 0)
                  - COALESCE(w.total_withdrawn, 0)
                  - (ac.auto_nft_count * 1100)
                  - GREATEST(0, ac.cum_usdt - 1100)
              )
          ) > 10
    ) sub;

    check_name := 'available_usdt整合性(差>$10)';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;

    -- ========================================
    -- CHECK 4: NFTカウント整合性
    -- ========================================
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'user_id', sub.user_id,
        'cycle_total', sub.cycle_total,
        'actual_total', sub.actual_total
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT
            ac.user_id,
            ac.total_nft_count as cycle_total,
            COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_total
        FROM affiliate_cycle ac
        LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
        GROUP BY ac.user_id, ac.total_nft_count
        HAVING ac.total_nft_count != COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL)
    ) sub;

    check_name := 'NFTカウント整合性';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION check_monthly_integrity(INTEGER, INTEGER) TO authenticated;

-- ========== STEP 3: 改良版で再チェック ==========

SELECT * FROM check_monthly_integrity(2026, 4);

-- ========== 完了 ==========
SELECT '✅ 9A3A16のNFTカウント修正とcheck関数改良が完了しました' as status;
