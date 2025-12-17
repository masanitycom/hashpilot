-- ========================================
-- 12/15運用開始ユーザーの日利補填（シンプル版）
-- ========================================
-- 実行日: 2025-12-17
--
-- user_daily_profitはビューなので、nft_daily_profitのみに挿入
-- affiliate_cycleも更新
-- ========================================

-- ========================================
-- STEP 1: 12/15と12/16のprofit_per_nftを確認
-- ========================================
SELECT '【確認】12/15と12/16の日利設定' as section;

SELECT
  date,
  profit_per_nft
FROM daily_yield_log_v2
WHERE date IN ('2025-12-15', '2025-12-16')
ORDER BY date;

-- ========================================
-- STEP 2: 補填対象ユーザーを確認（12/15）
-- ========================================
SELECT '【確認】12/15補填対象ユーザー' as section;

SELECT
  u.user_id,
  COUNT(nm.id) as nft_count,
  u.operation_start_date
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date = '2025-12-15'
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND NOT EXISTS (
    SELECT 1 FROM nft_daily_profit ndp
    WHERE ndp.user_id = u.user_id AND ndp.date = '2025-12-15'
  )
GROUP BY u.user_id, u.operation_start_date
ORDER BY u.user_id;

-- ========================================
-- STEP 3: 12/15の日利を補填（nft_daily_profitに挿入）
-- ========================================
SELECT '【実行】12/15の日利を補填' as section;

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
)
SELECT
  nm.id as nft_id,
  nm.user_id,
  '2025-12-15'::DATE as date,
  (SELECT profit_per_nft FROM daily_yield_log_v2 WHERE date = '2025-12-15') as daily_profit,
  NULL as yield_rate,
  NULL as user_rate,
  1000 as base_amount,
  'DIVIDEND' as phase,
  NOW() as created_at
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date = '2025-12-15'
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND NOT EXISTS (
    SELECT 1 FROM nft_daily_profit ndp
    WHERE ndp.nft_id = nm.id AND ndp.date = '2025-12-15'
  );

-- ========================================
-- STEP 4: 12/16の日利を補填（nft_daily_profitに挿入）
-- ========================================
SELECT '【実行】12/16の日利を補填' as section;

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
)
SELECT
  nm.id as nft_id,
  nm.user_id,
  '2025-12-16'::DATE as date,
  (SELECT profit_per_nft FROM daily_yield_log_v2 WHERE date = '2025-12-16') as daily_profit,
  NULL as yield_rate,
  NULL as user_rate,
  1000 as base_amount,
  'DIVIDEND' as phase,
  NOW() as created_at
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.has_approved_nft = true
  AND u.operation_start_date <= '2025-12-16'
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND NOT EXISTS (
    SELECT 1 FROM nft_daily_profit ndp
    WHERE ndp.nft_id = nm.id AND ndp.date = '2025-12-16'
  );

-- ========================================
-- STEP 5: affiliate_cycleのavailable_usdtを更新（12/15分）
-- ========================================
SELECT '【実行】affiliate_cycleを更新（12/15分）' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = ac.available_usdt + sub.total_profit,
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE date = '2025-12-15'
    AND user_id IN (
      SELECT user_id FROM users WHERE operation_start_date = '2025-12-15'
    )
    AND created_at > NOW() - INTERVAL '10 minutes'  -- 今回挿入分のみ
  GROUP BY user_id
) sub
WHERE ac.user_id = sub.user_id;

-- ========================================
-- STEP 6: affiliate_cycleのavailable_usdtを更新（12/16分）
-- ========================================
SELECT '【実行】affiliate_cycleを更新（12/16分）' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = ac.available_usdt + sub.total_profit,
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE date = '2025-12-16'
    AND created_at > NOW() - INTERVAL '10 minutes'  -- 今回挿入分のみ
  GROUP BY user_id
) sub
WHERE ac.user_id = sub.user_id;

-- ========================================
-- STEP 7: 補填結果を確認
-- ========================================
SELECT '【確認】補填結果' as section;

SELECT
  u.user_id,
  u.operation_start_date,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count,
  (SELECT SUM(ndp.daily_profit) FROM nft_daily_profit ndp WHERE ndp.user_id = u.user_id AND ndp.date = '2025-12-15') as profit_1215,
  (SELECT SUM(ndp.daily_profit) FROM nft_daily_profit ndp WHERE ndp.user_id = u.user_id AND ndp.date = '2025-12-16') as profit_1216,
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
  '12/15補填NFT数' as metric,
  COUNT(*) as value
FROM nft_daily_profit
WHERE date = '2025-12-15'
  AND created_at > NOW() - INTERVAL '10 minutes';

SELECT
  '12/16補填NFT数' as metric,
  COUNT(*) as value
FROM nft_daily_profit
WHERE date = '2025-12-16'
  AND created_at > NOW() - INTERVAL '10 minutes';
