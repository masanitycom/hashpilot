-- ========================================
-- 1/3のNFT数問題調査
-- ========================================

-- 1. daily_yield_log_v2の1/3データ
SELECT '=== 1/3の日利ログ ===' as section;
SELECT * FROM daily_yield_log_v2 WHERE date = '2026-01-03';

-- 2. 1/1, 1/2, 1/3の比較
SELECT '=== 1/1〜1/3の比較 ===' as section;
SELECT date, total_nft_count, profit_per_nft, total_profit_amount
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-03'
ORDER BY date;

-- 3. 1/3に配布されたNFT数（nft_daily_profit）
SELECT '=== 1/3に配布されたNFT数 ===' as section;
SELECT COUNT(*) as nft_count FROM nft_daily_profit WHERE date = '2026-01-03';

-- 4. 運用開始前のNFT（1/15運用開始のはず）
SELECT '=== 運用開始が1/15のユーザー ===' as section;
SELECT
  u.user_id,
  u.operation_start_date,
  nm.nft_type,
  nm.acquired_date
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2026-01-15'
  AND nm.buyback_date IS NULL;

-- 5. 59C23CとA94B2Bの確認
SELECT '=== 59C23CとA94B2Bの状況 ===' as section;
SELECT
  u.user_id,
  u.operation_start_date,
  COUNT(nm.id) as nft_count
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.user_id IN ('59C23C', 'A94B2B')
  AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.operation_start_date;

-- 6. 1/3に59C23CとA94B2Bに配布されているか
SELECT '=== 1/3に59C23C/A94B2Bへの配布 ===' as section;
SELECT
  ndp.nft_id,
  nm.user_id,
  ndp.date,
  ndp.daily_profit
FROM nft_daily_profit ndp
JOIN nft_master nm ON ndp.nft_id = nm.id
WHERE nm.user_id IN ('59C23C', 'A94B2B')
  AND ndp.date = '2026-01-03';
