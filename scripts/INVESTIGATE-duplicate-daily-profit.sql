-- ========================================
-- 日利の重複レコード調査
-- ========================================
-- 発見: ACACDBは毎日12レコードが存在（NFT12個分？）
-- 問題: 日利はユーザー×日付で1レコードであるべき
-- ========================================

-- 調査1: 日付ごとのレコード数（ACACDBの例）
SELECT '=== 1. ACACDB: 日付別レコード数 ===' as section;
SELECT
  date,
  COUNT(*) as record_count,
  SUM(daily_profit) as daily_total
FROM nft_daily_profit
WHERE user_id = 'ACACDB'
GROUP BY date
ORDER BY date;

-- 調査2: 重複レコードを持つ全ユーザー
SELECT '=== 2. 日付ごとに複数レコードを持つユーザー ===' as section;
SELECT
  user_id,
  date,
  COUNT(*) as record_count,
  SUM(daily_profit) as daily_total
FROM nft_daily_profit
GROUP BY user_id, date
HAVING COUNT(*) > 1
ORDER BY record_count DESC, user_id, date
LIMIT 50;

-- 調査3: ユーザーごとの重複統計
SELECT '=== 3. ユーザー別: 重複の影響 ===' as section;
SELECT
  user_id,
  COUNT(*) as total_records,
  COUNT(DISTINCT date) as unique_dates,
  ROUND(COUNT(*)::numeric / COUNT(DISTINCT date), 1) as avg_records_per_day,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
GROUP BY user_id
HAVING COUNT(*) > COUNT(DISTINCT date)
ORDER BY COUNT(*)::numeric / COUNT(DISTINCT date) DESC
LIMIT 30;

-- 調査4: 各ユーザーのNFT保有数との比較
SELECT '=== 4. NFT保有数 vs レコード数/日 ===' as section;
SELECT
  ndp.user_id,
  COUNT(DISTINCT ndp.date) as days_with_profit,
  COUNT(*) as total_records,
  ROUND(COUNT(*)::numeric / COUNT(DISTINCT ndp.date), 1) as records_per_day,
  nm.nft_count,
  CASE
    WHEN ROUND(COUNT(*)::numeric / COUNT(DISTINCT ndp.date), 1) = nm.nft_count THEN '✓ NFT数と一致'
    ELSE '❌ 不一致'
  END as status
FROM nft_daily_profit ndp
LEFT JOIN (
  SELECT user_id, COUNT(*) as nft_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm ON ndp.user_id = nm.user_id
GROUP BY ndp.user_id, nm.nft_count
HAVING ROUND(COUNT(*)::numeric / COUNT(DISTINCT ndp.date), 1) > 1
ORDER BY records_per_day DESC
LIMIT 30;

-- 調査5: 本来の合計 vs 重複ありの合計
SELECT '=== 5. 重複による過剰額の計算 ===' as section;
WITH daily_sums AS (
  SELECT
    user_id,
    date,
    SUM(daily_profit) as daily_total,
    COUNT(*) as record_count
  FROM nft_daily_profit
  GROUP BY user_id, date
),
user_stats AS (
  SELECT
    user_id,
    SUM(daily_total) as current_total,
    SUM(daily_total / record_count) as correct_total,
    SUM(daily_total) - SUM(daily_total / record_count) as over_amount
  FROM daily_sums
  WHERE record_count > 1
  GROUP BY user_id
)
SELECT
  us.user_id,
  u.operation_start_date,
  ROUND(us.current_total, 2) as current_profit,
  ROUND(us.correct_total, 2) as correct_profit,
  ROUND(us.over_amount, 2) as over_amount
FROM user_stats us
JOIN users u ON us.user_id = u.user_id
WHERE us.over_amount > 1
ORDER BY us.over_amount DESC
LIMIT 30;

-- 調査6: process_daily_yield_v2の動作確認
-- なぜNFTごとにレコードが作成されているか
SELECT '=== 6. 12月1日のデータ構造確認 ===' as section;
SELECT
  user_id,
  date,
  daily_profit,
  created_at
FROM nft_daily_profit
WHERE date = '2025-12-01'
  AND user_id = 'ACACDB'
ORDER BY created_at;
