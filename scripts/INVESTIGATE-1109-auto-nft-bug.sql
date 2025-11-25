-- ========================================
-- 11/9マイナス日利時の自動NFT付与バグ調査
-- ========================================
-- 問題: マイナス$5000の日利設定なのに、NFTが692個→834個に増加（+142個）
--       画面には「NFT自動付与: 15件に付与」と表示
-- ========================================

-- 1. 11/9の日利設定を確認
SELECT
  date,
  total_profit_amount,
  total_nft_count,
  profit_per_nft,
  daily_pnl,
  distribution_dividend,
  distribution_affiliate,
  distribution_stock
FROM daily_yield_log_v2
WHERE date = '2025-11-09'
ORDER BY date DESC;

-- 2. 11/9に自動NFT付与されたユーザーを確認
SELECT
  u.user_id,
  u.email,
  u.operation_start_date,
  u.has_approved_nft,
  ac.cum_usdt,
  ac.available_usdt,
  ac.auto_nft_count,
  ac.phase
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE nm.acquired_date = '2025-11-09'
  AND nm.nft_type = 'auto'
ORDER BY u.user_id;

-- 3. 11/9の自動NFT付与数を確認
SELECT COUNT(*) as auto_nft_count_1109
FROM nft_master
WHERE acquired_date = '2025-11-09'
  AND nft_type = 'auto';

-- 4. 11/9の自動NFT付与で、運用開始前のユーザーがいるか確認
SELECT
  u.user_id,
  u.email,
  u.operation_start_date,
  nm.acquired_date,
  ac.cum_usdt,
  ac.auto_nft_count,
  CASE
    WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
    WHEN u.operation_start_date > '2025-11-09' THEN '運用開始前'
    ELSE '運用中'
  END as status,
  COUNT(nm.id) as nft_count_1109
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE nm.acquired_date = '2025-11-09'
  AND nm.nft_type = 'auto'
GROUP BY u.user_id, u.email, u.operation_start_date, nm.acquired_date,
         ac.cum_usdt, ac.auto_nft_count
ORDER BY u.user_id;

-- 5. 11/8→11/9のNFT数変化を確認（管理画面の表示と一致するか）
WITH nft_counts AS (
  SELECT
    '2025-11-08' as date,
    COUNT(*) as nft_count
  FROM nft_master
  WHERE acquired_date <= '2025-11-08'
    AND (buyback_date IS NULL OR buyback_date > '2025-11-08')
  UNION ALL
  SELECT
    '2025-11-09' as date,
    COUNT(*) as nft_count
  FROM nft_master
  WHERE acquired_date <= '2025-11-09'
    AND (buyback_date IS NULL OR buyback_date > '2025-11-09')
)
SELECT
  date,
  nft_count,
  nft_count - LAG(nft_count) OVER (ORDER BY date) as increase
FROM nft_counts
ORDER BY date;

-- 6. 11/9の紹介報酬を確認（マイナス日利なので0のはず）
SELECT
  COUNT(DISTINCT user_id) as user_count,
  COUNT(*) as referral_count,
  SUM(profit_amount) as total_referral_profit
FROM user_referral_profit
WHERE date = '2025-11-09';

-- 7. 11/9の個人利益配布を確認（マイナスのはず）
SELECT
  COUNT(DISTINCT user_id) as user_count,
  COUNT(*) as nft_count,
  SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE date = '2025-11-09';

-- 8. 11/8時点でcum_usdt >= 2200のユーザー数を確認
-- （11/9の自動NFT付与対象者の推定）
SELECT
  COUNT(*) as eligible_users,
  SUM(CASE WHEN u.operation_start_date IS NULL THEN 1 ELSE 0 END) as null_start_date,
  SUM(CASE WHEN u.operation_start_date > '2025-11-09' THEN 1 ELSE 0 END) as future_start_date,
  SUM(CASE WHEN u.operation_start_date IS NOT NULL AND u.operation_start_date <= '2025-11-09' THEN 1 ELSE 0 END) as valid_users
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.cum_usdt >= 2200;

-- 9. 11/9に手動NFTも追加されたか確認（自動vs手動）
SELECT
  nft_type,
  COUNT(*) as nft_count
FROM nft_master
WHERE acquired_date = '2025-11-09'
GROUP BY nft_type
ORDER BY nft_type;

-- 10. 管理画面の表示値を再計算（デバッグ用）
-- 11/9の total_nft_count は何を数えているか？
SELECT
  'ペガサス除外（運用中のみ）' as criteria,
  COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-11-09'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);
