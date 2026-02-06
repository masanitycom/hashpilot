-- ========================================
-- 月中NFT変動ユーザーの検出
-- ========================================

-- 2026年1月に運用開始したNFTを持つユーザー（月中変動あり）
SELECT '=== 1月中にNFT追加されたユーザー ===' as section;
WITH nft_changes AS (
  SELECT
    nm.user_id,
    COUNT(*) FILTER (WHERE nm.operation_start_date < '2026-01-01') as nft_before_jan,
    COUNT(*) FILTER (WHERE nm.operation_start_date >= '2026-01-01' AND nm.operation_start_date <= '2026-01-31') as nft_added_jan,
    COUNT(*) as total_nft,
    MIN(CASE WHEN nm.operation_start_date >= '2026-01-01' AND nm.operation_start_date <= '2026-01-31'
        THEN nm.operation_start_date END) as first_jan_addition_date,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto') as auto_nft_count
  FROM nft_master nm
  WHERE nm.buyback_date IS NULL
  GROUP BY nm.user_id
)
SELECT
  nc.user_id,
  nc.nft_before_jan as "月初NFT",
  nc.nft_added_jan as "月中追加",
  nc.total_nft as "月末NFT",
  nc.first_jan_addition_date as "追加日",
  nc.auto_nft_count as "自動NFT",
  ROUND(COALESCE(SUM(ndp.daily_profit), 0)::numeric, 2) as "1月利益"
FROM nft_changes nc
LEFT JOIN nft_daily_profit ndp ON nc.user_id = ndp.user_id
  AND ndp.date >= '2026-01-01' AND ndp.date <= '2026-01-31'
WHERE nc.nft_added_jan > 0
GROUP BY nc.user_id, nc.nft_before_jan, nc.nft_added_jan, nc.total_nft, nc.first_jan_addition_date, nc.auto_nft_count
ORDER BY nc.first_jan_addition_date, nc.user_id;

-- 自動NFT保有者一覧
SELECT '=== 自動NFT保有者 ===' as section;
SELECT
  nm.user_id,
  COUNT(*) FILTER (WHERE nm.nft_type = 'auto') as "自動NFT数",
  COUNT(*) FILTER (WHERE nm.nft_type = 'manual') as "手動NFT数",
  COUNT(*) as "合計NFT",
  STRING_AGG(
    CASE WHEN nm.nft_type = 'auto'
      THEN nm.operation_start_date::text
    END, ', '
  ) as "自動NFT運用開始日"
FROM nft_master nm
WHERE nm.buyback_date IS NULL
GROUP BY nm.user_id
HAVING COUNT(*) FILTER (WHERE nm.nft_type = 'auto') > 0
ORDER BY COUNT(*) FILTER (WHERE nm.nft_type = 'auto') DESC;
