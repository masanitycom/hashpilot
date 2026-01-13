-- ========================================
-- 全データの整合性を包括的にチェック
-- 実行日: 2026-01-13
-- ========================================

-- ========================================
-- CHECK 1: 1月に作成された全ての自動NFT
-- （日次処理で誤って作成された可能性）
-- ========================================
SELECT '=== CHECK 1: 1月の自動NFT全件 ===' as section;

SELECT
  nm.user_id,
  nm.id as nft_id,
  nm.nft_sequence,
  nm.nft_type,
  nm.acquired_date,
  nm.created_at,
  ac.auto_nft_count as "affiliate_cycleのauto_nft_count",
  (SELECT COUNT(*) FROM nft_master WHERE user_id = nm.user_id AND nft_type = 'auto') as "実際のauto_nft数"
FROM nft_master nm
LEFT JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
WHERE nm.nft_type = 'auto'
  AND nm.acquired_date >= '2026-01-01'
ORDER BY nm.acquired_date, nm.user_id;

-- ========================================
-- CHECK 2: auto_nft_countと実際のNFT数の不一致
-- ========================================
SELECT '=== CHECK 2: auto_nft_count不一致ユーザー ===' as section;

SELECT
  ac.user_id,
  ac.auto_nft_count as "affiliate_cycleのcount",
  COUNT(nm.id) as "実際のauto_nft数",
  ac.auto_nft_count - COUNT(nm.id) as "差分"
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
GROUP BY ac.user_id, ac.auto_nft_count
HAVING ac.auto_nft_count != COUNT(nm.id)
ORDER BY ABS(ac.auto_nft_count - COUNT(nm.id)) DESC;

-- ========================================
-- CHECK 3: cum_usdtとmonthly_referral_profitの不一致
-- （NFT自動付与による減算を考慮）
-- ========================================
SELECT '=== CHECK 3: cum_usdt不一致ユーザー ===' as section;

SELECT
  ac.user_id,
  ac.cum_usdt as "現在のcum_usdt",
  COALESCE(mrp.total, 0) as "月次紹介報酬累計",
  ac.auto_nft_count as "自動NFT数",
  ac.auto_nft_count * 1100 as "NFT購入による減算",
  COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100) as "期待されるcum_usdt",
  ac.cum_usdt - (COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100)) as "差分"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(ac.cum_usdt - (COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100))) > 1
ORDER BY ABS(ac.cum_usdt - (COALESCE(mrp.total, 0) - (ac.auto_nft_count * 1100))) DESC
LIMIT 20;

-- ========================================
-- CHECK 4: total_nft_countの不一致
-- ========================================
SELECT '=== CHECK 4: total_nft_count不一致ユーザー ===' as section;

SELECT
  ac.user_id,
  ac.manual_nft_count,
  ac.auto_nft_count,
  ac.total_nft_count as "affiliate_cycleのtotal",
  ac.manual_nft_count + ac.auto_nft_count as "manual+auto",
  COUNT(nm.id) as "実際のNFT数（buyback除く）"
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.buyback_date IS NULL
GROUP BY ac.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count
HAVING ac.total_nft_count != COUNT(nm.id)
   OR ac.total_nft_count != (ac.manual_nft_count + ac.auto_nft_count)
ORDER BY ac.user_id;

-- ========================================
-- CHECK 5: 1月の日次紹介報酬データ詳細
-- ========================================
SELECT '=== CHECK 5: 1月日次紹介報酬データ（ユーザー別） ===' as section;

SELECT
  user_id,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount,
  MIN(date) as min_date,
  MAX(date) as max_date
FROM user_referral_profit
WHERE date >= '2026-01-01'
GROUP BY user_id
ORDER BY SUM(profit_amount) DESC
LIMIT 20;

-- ========================================
-- CHECK 6: phaseの整合性
-- cum_usdt >= 1100 ならHOLD、< 1100 ならUSDT
-- ========================================
SELECT '=== CHECK 6: phase不整合ユーザー ===' as section;

SELECT
  user_id,
  cum_usdt,
  phase,
  CASE
    WHEN cum_usdt >= 1100 THEN 'HOLD'
    ELSE 'USDT'
  END as "期待されるphase"
FROM affiliate_cycle
WHERE phase != CASE WHEN cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END
ORDER BY cum_usdt DESC;

-- ========================================
-- CHECK 7: 1/1以外の自動NFT（月末以外で作成された不正NFT）
-- ========================================
SELECT '=== CHECK 7: 月末以外に作成された自動NFT ===' as section;

SELECT
  nm.user_id,
  nm.id as nft_id,
  nm.acquired_date,
  nm.created_at,
  EXTRACT(DAY FROM nm.acquired_date) as day_of_month
FROM nft_master nm
WHERE nm.nft_type = 'auto'
  AND EXTRACT(DAY FROM nm.acquired_date) NOT IN (1, 28, 29, 30, 31)  -- 月末/月初以外
ORDER BY nm.acquired_date;

-- ========================================
-- CHECK 8: available_usdtの整合性確認
-- ========================================
SELECT '=== CHECK 8: available_usdt確認（上位20） ===' as section;

SELECT
  ac.user_id,
  ac.available_usdt,
  COALESCE(ndp.total_profit, 0) as "日次利益累計",
  COALESCE(mrp_usdt.usdt_phase_referral, 0) as "USDTフェーズ紹介報酬",
  ac.auto_nft_count * 1100 as "NFT付与時の加算",
  ac.withdrawn_referral_usdt as "出金済み紹介報酬"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) ndp ON ac.user_id = ndp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as usdt_phase_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp_usdt ON ac.user_id = mrp_usdt.user_id
ORDER BY ac.available_usdt DESC
LIMIT 20;

-- ========================================
-- SUMMARY: 問題の総数
-- ========================================
SELECT '=== SUMMARY: 問題の総数 ===' as section;

SELECT 'auto_nft_count不一致' as issue_type, COUNT(*) as count
FROM (
  SELECT ac.user_id
  FROM affiliate_cycle ac
  LEFT JOIN nft_master nm ON ac.user_id = nm.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
  GROUP BY ac.user_id, ac.auto_nft_count
  HAVING ac.auto_nft_count != COUNT(nm.id)
) t
UNION ALL
SELECT 'phase不整合' as issue_type, COUNT(*) as count
FROM affiliate_cycle
WHERE phase != CASE WHEN cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END
UNION ALL
SELECT '1月日次紹介報酬データ' as issue_type, COUNT(DISTINCT user_id) as count
FROM user_referral_profit
WHERE date >= '2026-01-01'
UNION ALL
SELECT '月末以外の自動NFT' as issue_type, COUNT(*) as count
FROM nft_master
WHERE nft_type = 'auto'
  AND EXTRACT(DAY FROM acquired_date) NOT IN (1, 28, 29, 30, 31);
