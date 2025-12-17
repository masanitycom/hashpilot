-- ========================================
-- 12/15運用開始ユーザーの日利補填スクリプト
-- ========================================
-- 実行日: 2025-12-17
--
-- 問題:
-- - approve_user_nft関数のバグでhas_approved_nftとoperation_start_dateが未設定
-- - 12/15運用開始ユーザーが12/15-12/16の日利を受け取れなかった
--
-- このスクリプトの処理:
-- 1. 問題ユーザーのhas_approved_nftとoperation_start_dateを修正
-- 2. 12/15と12/16の日利を補填
-- 3. affiliate_cycleのavailable_usdtを更新
-- ========================================

-- ========================================
-- STEP 1: 問題ユーザーの確認
-- ========================================
SELECT '【STEP 1】問題ユーザーの確認' as section;

SELECT
  u.user_id,
  u.email,
  u.has_approved_nft,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as active_nft_count,
  (SELECT MIN(p.admin_approved_at) FROM purchases p WHERE p.user_id = u.user_id AND p.admin_approved = true) as first_approval_date
FROM users u
WHERE
  EXISTS (
    SELECT 1 FROM nft_master nm
    WHERE nm.user_id = u.user_id
      AND nm.buyback_date IS NULL
  )
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL OR u.operation_start_date IS NULL)
ORDER BY u.user_id;

-- ========================================
-- STEP 2: has_approved_nftを修正
-- ========================================
SELECT '【STEP 2】has_approved_nftをtrueに設定' as section;

UPDATE users u
SET
  has_approved_nft = true,
  updated_at = NOW()
WHERE
  EXISTS (
    SELECT 1 FROM nft_master nm
    WHERE nm.user_id = u.user_id
      AND nm.buyback_date IS NULL
  )
  AND (u.has_approved_nft = false OR u.has_approved_nft IS NULL);

-- ========================================
-- STEP 3: operation_start_dateを修正
-- ========================================
SELECT '【STEP 3】operation_start_dateを設定' as section;

UPDATE users u
SET
  operation_start_date = calculate_operation_start_date(
    (SELECT MIN(p.admin_approved_at)
     FROM purchases p
     WHERE p.user_id = u.user_id
       AND p.admin_approved = true)
  ),
  updated_at = NOW()
WHERE
  u.operation_start_date IS NULL
  AND EXISTS (
    SELECT 1 FROM purchases p
    WHERE p.user_id = u.user_id
      AND p.admin_approved = true
  );

-- ========================================
-- STEP 4: 12/15の日利ログを取得
-- ========================================
SELECT '【STEP 4】12/15と12/16の日利設定を確認' as section;

SELECT
  date,
  total_nft_count,
  profit_per_nft,
  distribution_dividend
FROM daily_yield_log_v2
WHERE date IN ('2025-12-15', '2025-12-16')
ORDER BY date;

-- ========================================
-- STEP 5: 12/15運用開始ユーザーで日利未配布のユーザーを特定
-- ========================================
SELECT '【STEP 5】12/15運用開始で日利未配布のユーザー' as section;

SELECT
  u.user_id,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count,
  (SELECT COUNT(*) FROM user_daily_profit udp WHERE udp.user_id = u.user_id AND udp.date = '2025-12-15') as profit_1215_count,
  (SELECT COUNT(*) FROM user_daily_profit udp WHERE udp.user_id = u.user_id AND udp.date = '2025-12-16') as profit_1216_count
FROM users u
WHERE u.operation_start_date = '2025-12-15'
  AND u.has_approved_nft = true
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
ORDER BY u.user_id;

-- ========================================
-- STEP 6: 12/15の日利を補填
-- ========================================
SELECT '【STEP 6】12/15の日利を補填' as section;

DO $$
DECLARE
  v_date DATE := '2025-12-15';
  v_profit_per_nft NUMERIC;
  v_user_record RECORD;
  v_nft_record RECORD;
  v_user_profit NUMERIC;
  v_total_distributed NUMERIC := 0;
  v_user_count INTEGER := 0;
BEGIN
  -- 12/15のprofit_per_nftを取得
  SELECT profit_per_nft INTO v_profit_per_nft
  FROM daily_yield_log_v2
  WHERE date = v_date;

  IF v_profit_per_nft IS NULL THEN
    RAISE NOTICE '12/15の日利ログが見つかりません';
    RETURN;
  END IF;

  RAISE NOTICE '12/15のprofit_per_nft: %', v_profit_per_nft;

  -- 12/15運用開始ユーザーで、12/15の日利が未配布のユーザーを処理
  FOR v_user_record IN
    SELECT
      u.user_id,
      COUNT(nm.id) as nft_count
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    WHERE nm.buyback_date IS NULL
      AND u.has_approved_nft = true
      AND u.operation_start_date = '2025-12-15'
      AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
      AND NOT EXISTS (
        SELECT 1 FROM user_daily_profit udp
        WHERE udp.user_id = u.user_id AND udp.date = v_date
      )
    GROUP BY u.user_id
  LOOP
    v_user_profit := v_profit_per_nft * v_user_record.nft_count;

    -- user_daily_profitに記録
    INSERT INTO user_daily_profit (
      user_id,
      date,
      daily_profit,
      phase,
      created_at
    ) VALUES (
      v_user_record.user_id,
      v_date,
      v_user_profit,
      'DIVIDEND',
      NOW()
    );

    -- nft_daily_profitに記録（各NFTごと）
    FOR v_nft_record IN
      SELECT id as nft_id
      FROM nft_master
      WHERE user_id = v_user_record.user_id
        AND buyback_date IS NULL
    LOOP
      INSERT INTO nft_daily_profit (
        nft_id,
        user_id,
        date,
        daily_profit,
        yield_rate,
        user_rate,
        base_amount,
        phase,
        created_at
      ) VALUES (
        v_nft_record.nft_id,
        v_user_record.user_id,
        v_date,
        v_profit_per_nft,
        NULL,
        NULL,
        1000,
        'DIVIDEND',
        NOW()
      );
    END LOOP;

    -- affiliate_cycleのavailable_usdtに加算
    UPDATE affiliate_cycle
    SET
      available_usdt = available_usdt + v_user_profit,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_total_distributed := v_total_distributed + v_user_profit;
    v_user_count := v_user_count + 1;

    RAISE NOTICE 'ユーザー % に $% を補填（NFT数: %）', v_user_record.user_id, v_user_profit, v_user_record.nft_count;
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE '12/15補填完了: %名に合計$%を配布', v_user_count, v_total_distributed;
  RAISE NOTICE '========================================';
END $$;

-- ========================================
-- STEP 7: 12/16の日利を補填
-- ========================================
SELECT '【STEP 7】12/16の日利を補填' as section;

DO $$
DECLARE
  v_date DATE := '2025-12-16';
  v_profit_per_nft NUMERIC;
  v_user_record RECORD;
  v_nft_record RECORD;
  v_user_profit NUMERIC;
  v_total_distributed NUMERIC := 0;
  v_user_count INTEGER := 0;
BEGIN
  -- 12/16のprofit_per_nftを取得
  SELECT profit_per_nft INTO v_profit_per_nft
  FROM daily_yield_log_v2
  WHERE date = v_date;

  IF v_profit_per_nft IS NULL THEN
    RAISE NOTICE '12/16の日利ログが見つかりません';
    RETURN;
  END IF;

  RAISE NOTICE '12/16のprofit_per_nft: %', v_profit_per_nft;

  -- 12/15運用開始ユーザーで、12/16の日利が未配布のユーザーを処理
  FOR v_user_record IN
    SELECT
      u.user_id,
      COUNT(nm.id) as nft_count
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    WHERE nm.buyback_date IS NULL
      AND u.has_approved_nft = true
      AND u.operation_start_date <= v_date  -- 12/15以前の運用開始日も含む
      AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
      AND NOT EXISTS (
        SELECT 1 FROM user_daily_profit udp
        WHERE udp.user_id = u.user_id AND udp.date = v_date
      )
    GROUP BY u.user_id
  LOOP
    v_user_profit := v_profit_per_nft * v_user_record.nft_count;

    -- user_daily_profitに記録
    INSERT INTO user_daily_profit (
      user_id,
      date,
      daily_profit,
      phase,
      created_at
    ) VALUES (
      v_user_record.user_id,
      v_date,
      v_user_profit,
      'DIVIDEND',
      NOW()
    );

    -- nft_daily_profitに記録（各NFTごと）
    FOR v_nft_record IN
      SELECT id as nft_id
      FROM nft_master
      WHERE user_id = v_user_record.user_id
        AND buyback_date IS NULL
    LOOP
      INSERT INTO nft_daily_profit (
        nft_id,
        user_id,
        date,
        daily_profit,
        yield_rate,
        user_rate,
        base_amount,
        phase,
        created_at
      ) VALUES (
        v_nft_record.nft_id,
        v_user_record.user_id,
        v_date,
        v_profit_per_nft,
        NULL,
        NULL,
        1000,
        'DIVIDEND',
        NOW()
      );
    END LOOP;

    -- affiliate_cycleのavailable_usdtに加算
    UPDATE affiliate_cycle
    SET
      available_usdt = available_usdt + v_user_profit,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_total_distributed := v_total_distributed + v_user_profit;
    v_user_count := v_user_count + 1;

    RAISE NOTICE 'ユーザー % に $% を補填（NFT数: %）', v_user_record.user_id, v_user_profit, v_user_record.nft_count;
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE '12/16補填完了: %名に合計$%を配布', v_user_count, v_total_distributed;
  RAISE NOTICE '========================================';
END $$;

-- ========================================
-- STEP 8: 補填結果の確認
-- ========================================
SELECT '【STEP 8】補填結果の確認' as section;

SELECT
  u.user_id,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count,
  (SELECT SUM(udp.daily_profit) FROM user_daily_profit udp WHERE udp.user_id = u.user_id AND udp.date = '2025-12-15') as profit_1215,
  (SELECT SUM(udp.daily_profit) FROM user_daily_profit udp WHERE udp.user_id = u.user_id AND udp.date = '2025-12-16') as profit_1216,
  ac.available_usdt
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-12-15'
  AND u.has_approved_nft = true
ORDER BY u.user_id;

-- ========================================
-- サマリー
-- ========================================
SELECT '========================================' as separator;
SELECT '補填完了サマリー' as section;

SELECT
  '12/15配布ユーザー数' as metric,
  COUNT(DISTINCT user_id) as value
FROM user_daily_profit
WHERE date = '2025-12-15';

SELECT
  '12/16配布ユーザー数' as metric,
  COUNT(DISTINCT user_id) as value
FROM user_daily_profit
WHERE date = '2025-12-16';

SELECT
  '12/15運用開始ユーザーの12/15合計日利' as metric,
  COALESCE(SUM(udp.daily_profit), 0) as value
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE udp.date = '2025-12-15'
  AND u.operation_start_date = '2025-12-15';

SELECT
  '12/15運用開始ユーザーの12/16合計日利' as metric,
  COALESCE(SUM(udp.daily_profit), 0) as value
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE udp.date = '2025-12-16'
  AND u.operation_start_date = '2025-12-15';
