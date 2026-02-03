-- ========================================
-- ペガサスユーザー 1/1〜1/19 日利遡及配布
-- ========================================
-- 問題: ペガサス除外条件が誤って追加され、61人が1/1〜1/19の日利を受け取れなかった
-- 対象: is_pegasus_exchange = true AND operation_start_date IS NOT NULL

-- まず影響を確認
SELECT '=== 遡及配布対象の確認 ===' as section;

-- 対象ユーザー数
SELECT
  COUNT(*) as 対象ユーザー数,
  SUM(CASE WHEN operation_start_date <= '2026-01-01' THEN 1 ELSE 0 END) as 全日対象,
  SUM(CASE WHEN operation_start_date > '2026-01-01' AND operation_start_date <= '2026-01-19' THEN 1 ELSE 0 END) as 途中開始
FROM users
WHERE is_pegasus_exchange = true
  AND operation_start_date IS NOT NULL
  AND operation_start_date <= '2026-01-19';

-- 1/1〜1/19の日利ログを確認
SELECT '=== 1/1〜1/19の日利ログ ===' as section;
SELECT
  date,
  total_nft_count as NFT数,
  ROUND(profit_per_nft::numeric, 6) as NFT単価,
  ROUND(distribution_dividend::numeric, 2) as 配当60percent
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-19'
ORDER BY date;

-- 遡及配布実行
DO $$
DECLARE
  v_date DATE;
  v_yield_record RECORD;
  v_user_record RECORD;
  v_nft_record RECORD;
  v_total_nft_count INTEGER;
  v_user_profit NUMERIC;
  v_total_distributed NUMERIC := 0;
  v_total_users INTEGER := 0;
  v_total_records INTEGER := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ペガサスユーザー 1/1〜1/19 日利遡及配布開始';
  RAISE NOTICE '========================================';

  -- 1/1〜1/19の各日付をループ
  FOR v_date IN SELECT generate_series('2026-01-01'::date, '2026-01-19'::date, '1 day'::interval)::date
  LOOP
    -- その日の日利ログを取得
    SELECT
      total_nft_count,
      distribution_dividend
    INTO v_yield_record
    FROM daily_yield_log_v2
    WHERE date = v_date;

    IF v_yield_record IS NULL THEN
      RAISE NOTICE '日付 % の日利ログがありません。スキップします。', v_date;
      CONTINUE;
    END IF;

    -- ペガサスユーザーで、その日が運用開始日以降のユーザーをループ
    FOR v_user_record IN
      SELECT u.user_id, COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE u.is_pegasus_exchange = true
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= v_date
        AND nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= v_date
        -- 既に配布済みでないことを確認
        AND NOT EXISTS (
          SELECT 1 FROM nft_daily_profit ndp
          WHERE ndp.user_id = u.user_id
            AND ndp.date = v_date
        )
      GROUP BY u.user_id
    LOOP
      -- ユーザーの日利を計算
      v_user_profit := (v_yield_record.distribution_dividend / v_yield_record.total_nft_count) * v_user_record.nft_count;

      -- 各NFTに日利を配布
      FOR v_nft_record IN
        SELECT id as nft_id
        FROM nft_master
        WHERE user_id = v_user_record.user_id
          AND buyback_date IS NULL
          AND operation_start_date IS NOT NULL
          AND operation_start_date <= v_date
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id, user_id, date, daily_profit, yield_rate, user_rate,
          base_amount, phase, created_at
        ) VALUES (
          v_nft_record.nft_id, v_user_record.user_id, v_date,
          v_user_profit / v_user_record.nft_count, NULL, NULL,
          1000, 'DIVIDEND', NOW()
        );
        v_total_records := v_total_records + 1;
      END LOOP;

      -- affiliate_cycleを更新
      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_user_profit, updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
      v_total_users := v_total_users + 1;
    END LOOP;

    RAISE NOTICE '日付 % の遡及配布完了', v_date;
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE '完了: %ユーザー、%件、合計 $%', v_total_users, v_total_records, ROUND(v_total_distributed, 2);
  RAISE NOTICE '========================================';
END $$;

-- 結果確認
SELECT '=== 遡及配布後の確認 ===' as section;
SELECT
  u.user_id,
  u.email,
  u.operation_start_date,
  COUNT(DISTINCT ndp.date) as 日利配布日数,
  ROUND(SUM(ndp.daily_profit)::numeric, 2) as 日利合計
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE u.is_pegasus_exchange = true
  AND u.operation_start_date IS NOT NULL
GROUP BY u.user_id, u.email, u.operation_start_date
ORDER BY u.operation_start_date
LIMIT 10;
