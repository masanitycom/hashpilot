-- ========================================
-- 月末出金処理の修正前後の比較
-- ========================================

-- 現在の状況
SELECT '=== 1. 現在の出金レコード（2025年11月） ===' as section;

SELECT
    user_id,
    email,
    total_amount,
    withdrawal_method,
    status,
    task_completed,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
ORDER BY total_amount DESC;

-- 集計
SELECT
    COUNT(*) as current_count,
    SUM(total_amount) as current_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01';

-- 本来対象になるべきユーザー（available_usdt >= 10）
SELECT '=== 2. 本来の出金対象ユーザー（available_usdt >= 10） ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.available_usdt,
    u.coinw_uid,
    CASE
        WHEN u.coinw_uid IS NOT NULL AND u.coinw_uid != '' THEN 'CoinW設定済み'
        WHEN u.nft_receive_address IS NOT NULL AND u.nft_receive_address != '' THEN 'BEP20設定済み'
        ELSE '送金先未設定'
    END as withdrawal_method_status,
    CASE
        WHEN u.is_pegasus_exchange = true AND (
            u.pegasus_withdrawal_unlock_date IS NULL
            OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
        ) THEN 'ペガサス制限中'
        ELSE '制限なし'
    END as restriction_status,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM monthly_withdrawals mw
            WHERE mw.user_id = u.user_id
              AND mw.withdrawal_month = '2025-11-01'
        ) THEN '✅ レコードあり'
        ELSE '❌ レコードなし'
    END as has_record
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  )
ORDER BY ac.available_usdt DESC;

-- 集計
SELECT
    COUNT(*) as should_be_count,
    SUM(ac.available_usdt) as should_be_total
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

-- 欠落しているユーザー（レコードが作成されていないユーザー）
SELECT '=== 3. 欠落しているユーザー ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.available_usdt,
    CASE
        WHEN u.coinw_uid IS NOT NULL AND u.coinw_uid != '' THEN 'CoinW'
        WHEN u.nft_receive_address IS NOT NULL AND u.nft_receive_address != '' THEN 'BEP20'
        ELSE '未設定'
    END as withdrawal_method
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  )
  AND NOT EXISTS (
      SELECT 1 FROM monthly_withdrawals mw
      WHERE mw.user_id = u.user_id
        AND mw.withdrawal_month = '2025-11-01'
  )
ORDER BY ac.available_usdt DESC;

-- 欠落ユーザーの集計
SELECT
    COUNT(*) as missing_count,
    SUM(ac.available_usdt) as missing_total,
    MIN(ac.available_usdt) as min_amount,
    MAX(ac.available_usdt) as max_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  )
  AND NOT EXISTS (
      SELECT 1 FROM monthly_withdrawals mw
      WHERE mw.user_id = u.user_id
        AND mw.withdrawal_month = '2025-11-01'
  );

-- 金額帯別の分布
SELECT '=== 4. 欠落ユーザーの金額帯別分布 ===' as section;

SELECT
    CASE
        WHEN ac.available_usdt >= 100 THEN '$100以上'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        ELSE '$10～$19'
    END as amount_range,
    COUNT(*) as count,
    SUM(ac.available_usdt) as total_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  )
  AND NOT EXISTS (
      SELECT 1 FROM monthly_withdrawals mw
      WHERE mw.user_id = u.user_id
        AND mw.withdrawal_month = '2025-11-01'
  )
GROUP BY
    CASE
        WHEN ac.available_usdt >= 100 THEN '$100以上'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        ELSE '$10～$19'
    END
ORDER BY MIN(ac.available_usdt) DESC;

-- ペガサス制限ユーザー（除外される）
SELECT '=== 5. ペガサス制限ユーザー（除外対象） ===' as section;

SELECT
    u.user_id,
    u.email,
    u.full_name,
    ac.available_usdt,
    u.pegasus_withdrawal_unlock_date,
    CASE
        WHEN u.pegasus_withdrawal_unlock_date IS NULL THEN '解除日未設定'
        ELSE (u.pegasus_withdrawal_unlock_date - CURRENT_DATE)::TEXT || '日後に解除'
    END as days_until_unlock
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND u.is_pegasus_exchange = true
  AND (
      u.pegasus_withdrawal_unlock_date IS NULL
      OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
  )
ORDER BY ac.available_usdt DESC;

-- 最終サマリー
DO $$
DECLARE
    v_current_count INTEGER;
    v_current_total NUMERIC;
    v_should_count INTEGER;
    v_should_total NUMERIC;
    v_missing_count INTEGER;
    v_missing_total NUMERIC;
    v_pegasus_count INTEGER;
    v_pegasus_total NUMERIC;
BEGIN
    -- 現在のレコード数
    SELECT COUNT(*), COALESCE(SUM(total_amount), 0)
    INTO v_current_count, v_current_total
    FROM monthly_withdrawals
    WHERE withdrawal_month = '2025-11-01';

    -- 本来あるべきレコード数
    SELECT COUNT(*), COALESCE(SUM(ac.available_usdt), 0)
    INTO v_should_count, v_should_total
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

    -- 欠落しているレコード数
    v_missing_count := v_should_count - v_current_count;
    v_missing_total := v_should_total - v_current_total;

    -- ペガサス制限ユーザー
    SELECT COUNT(*), COALESCE(SUM(ac.available_usdt), 0)
    INTO v_pegasus_count, v_pegasus_total
    FROM users u
    INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.available_usdt >= 10
      AND u.is_pegasus_exchange = true
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      );

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 2025年11月 月末出金処理の状況';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '';
    RAISE NOTICE '【現在の状況】';
    RAISE NOTICE '  出金レコード: %件（総額: $%）', v_current_count, v_current_total;
    RAISE NOTICE '';
    RAISE NOTICE '【本来の対象ユーザー】';
    RAISE NOTICE '  対象ユーザー: %件（総額: $%）', v_should_count, v_should_total;
    RAISE NOTICE '';
    RAISE NOTICE '【欠落しているレコード】';
    RAISE NOTICE '  欠落件数: %件（総額: $%）', v_missing_count, v_missing_total;
    RAISE NOTICE '';
    RAISE NOTICE '【ペガサス制限で除外】';
    RAISE NOTICE '  除外件数: %件（総額: $%）', v_pegasus_count, v_pegasus_total;
    RAISE NOTICE '';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. FIX-monthly-withdrawals-minimum-amount.sql を実行';
    RAISE NOTICE '  2. REPROCESS-november-withdrawals.sql を実行';
    RAISE NOTICE '===========================================';
END $$;
