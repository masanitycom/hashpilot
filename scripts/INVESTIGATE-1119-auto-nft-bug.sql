-- ========================================
-- 11/19マイナス日利時の自動NFT付与バグ調査
-- ========================================

-- 1. 11/19の日利設定を確認
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
WHERE date = '2025-11-19'
ORDER BY date DESC;

-- 2. 11/19に自動NFT付与されたユーザーを確認
SELECT
  u.user_id,
  u.email,
  u.operation_start_date,
  u.has_approved_nft,
  ac.cum_usdt,
  ac.available_usdt,
  ac.auto_nft_count,
  ac.phase,
  COUNT(nm.id) as total_nft_count
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE nm.acquired_date = '2025-11-19'
  AND nm.nft_type = 'auto'
GROUP BY u.user_id, u.email, u.operation_start_date, u.has_approved_nft,
         ac.cum_usdt, ac.available_usdt, ac.auto_nft_count, ac.phase
ORDER BY u.user_id;

-- 3. 11/19の自動NFT付与数を確認
SELECT COUNT(*) as auto_nft_count
FROM nft_master
WHERE acquired_date = '2025-11-19'
  AND nft_type = 'auto';

-- 4. 11/19の自動NFT付与で、運用開始前のユーザーがいるか確認
SELECT
  u.user_id,
  u.email,
  u.operation_start_date,
  nm.acquired_date,
  ac.cum_usdt,
  ac.auto_nft_count,
  CASE
    WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
    WHEN u.operation_start_date > '2025-11-19' THEN '運用開始前'
    ELSE '運用中'
  END as status
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE nm.acquired_date = '2025-11-19'
  AND nm.nft_type = 'auto'
  AND (u.operation_start_date IS NULL OR u.operation_start_date > '2025-11-19')
ORDER BY u.user_id;

-- 5. 11/18→11/19のNFT数変化を確認
WITH nft_counts AS (
  SELECT
    '2025-11-18' as date,
    COUNT(*) as nft_count
  FROM nft_master
  WHERE acquired_date <= '2025-11-18'
    AND (buyback_date IS NULL OR buyback_date > '2025-11-18')
  UNION ALL
  SELECT
    '2025-11-19' as date,
    COUNT(*) as nft_count
  FROM nft_master
  WHERE acquired_date <= '2025-11-19'
    AND (buyback_date IS NULL OR buyback_date > '2025-11-19')
)
SELECT
  date,
  nft_count,
  nft_count - LAG(nft_count) OVER (ORDER BY date) as increase
FROM nft_counts
ORDER BY date;

-- 6. cum_usdt >= 2200のユーザーを確認（運用開始日別）
SELECT
  CASE
    WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
    WHEN u.operation_start_date > '2025-11-19' THEN '運用開始前'
    ELSE '運用中'
  END as status,
  COUNT(*) as user_count,
  SUM(ac.cum_usdt) as total_cum_usdt,
  SUM(ac.auto_nft_count) as total_auto_nft
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.cum_usdt >= 2200
GROUP BY
  CASE
    WHEN u.operation_start_date IS NULL THEN '運用開始日未設定'
    WHEN u.operation_start_date > '2025-11-19' THEN '運用開始前'
    ELSE '運用中'
  END
ORDER BY status;

-- 7. 11/19の紹介報酬を確認（マイナス日利なので0のはず）
SELECT
  COUNT(*) as referral_count,
  SUM(profit_amount) as total_referral_profit
FROM user_referral_profit
WHERE date = '2025-11-19';

-- 8. 11/19の個人利益配布を確認（マイナスのはず）
SELECT
  COUNT(*) as user_count,
  SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE date = '2025-11-19';
