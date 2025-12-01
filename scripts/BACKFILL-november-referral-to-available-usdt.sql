-- ========================================
-- 11月の紹介報酬をavailable_usdtに反映
-- ========================================

-- STEP 1: バックアップ作成
CREATE TABLE IF NOT EXISTS affiliate_cycle_backup_20251201 AS
SELECT * FROM affiliate_cycle;

SELECT '✅ バックアップ作成完了' as status,
       COUNT(*) as record_count
FROM affiliate_cycle_backup_20251201;

-- STEP 2: 11月の紹介報酬を集計
SELECT '=== 11月の紹介報酬集計 ===' as section;

WITH november_referral AS (
    SELECT
        user_id,
        SUM(profit_amount) as total_referral_profit
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30'
    GROUP BY user_id
)
SELECT
    COUNT(*) as users_with_referral,
    SUM(total_referral_profit) as total_amount,
    MIN(total_referral_profit) as min_amount,
    MAX(total_referral_profit) as max_amount,
    AVG(total_referral_profit) as avg_amount
FROM november_referral;

-- STEP 3: available_usdtに加算
UPDATE affiliate_cycle ac
SET
    available_usdt = available_usdt + COALESCE(nr.total_referral_profit, 0),
    updated_at = NOW()
FROM (
    SELECT
        user_id,
        SUM(profit_amount) as total_referral_profit
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30'
    GROUP BY user_id
) nr
WHERE ac.user_id = nr.user_id;

-- STEP 4: 結果確認
SELECT '=== 更新結果確認 ===' as section;

WITH november_referral AS (
    SELECT
        user_id,
        SUM(profit_amount) as total_referral_profit
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30'
    GROUP BY user_id
)
SELECT
    COUNT(*) as updated_users,
    SUM(nr.total_referral_profit) as total_added_amount
FROM november_referral nr;

-- STEP 5: 出金対象ユーザー数の再確認
SELECT '=== 出金対象ユーザー（更新後） ===' as section;

SELECT
    COUNT(*) as eligible_users,
    SUM(ac.available_usdt) as total_available
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  );

-- サマリー
DO $$
DECLARE
    v_before_count INTEGER;
    v_after_count INTEGER;
    v_added_amount NUMERIC;
BEGIN
    -- 更新前の出金対象（バックアップから計算）
    SELECT COUNT(*)
    INTO v_before_count
    FROM users u
    INNER JOIN affiliate_cycle_backup_20251201 ac ON u.user_id = ac.user_id
    WHERE ac.available_usdt >= 10
      AND NOT (
          COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
          AND (
              u.pegasus_withdrawal_unlock_date IS NULL
              OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
          )
      );

    -- 更新後の出金対象
    SELECT COUNT(*)
    INTO v_after_count
    FROM users u
    INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.available_usdt >= 10
      AND NOT (
          COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
          AND (
              u.pegasus_withdrawal_unlock_date IS NULL
              OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
          )
      );

    -- 加算された金額
    SELECT COALESCE(SUM(profit_amount), 0)
    INTO v_added_amount
    FROM user_referral_profit
    WHERE date >= '2025-11-01'
      AND date <= '2025-11-30';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 11月の紹介報酬反映完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '加算金額: $%', v_added_amount;
    RAISE NOTICE '';
    RAISE NOTICE '出金対象ユーザー:';
    RAISE NOTICE '  更新前: %名', v_before_count;
    RAISE NOTICE '  更新後: %名', v_after_count;
    RAISE NOTICE '  増加: %名', v_after_count - v_before_count;
    RAISE NOTICE '===========================================';
END $$;
