-- ========================================
-- 1月日利調整の影響確認
-- ========================================

-- 59C23Cと177B83の1月日利詳細
SELECT '=== 1月日利詳細 ===' as section;
SELECT 
  user_id,
  date,
  SUM(daily_profit) as 日利
FROM nft_daily_profit
WHERE user_id IN ('59C23C', '177B83')
  AND date >= '2026-01-01' AND date <= '2026-01-31'
GROUP BY user_id, date
ORDER BY user_id, date;

-- 1NFT保有者の1月個人利益（基準値確認）
SELECT '=== 1NFT保有者の1月個人利益サンプル ===' as section;
SELECT 
  ndp.user_id,
  SUM(ndp.daily_profit) as 個人利益
FROM nft_daily_profit ndp
JOIN affiliate_cycle ac ON ndp.user_id = ac.user_id
WHERE ndp.date >= '2026-01-01' AND ndp.date <= '2026-01-31'
  AND ac.total_nft_count = 1
  AND ac.auto_nft_count = 0
GROUP BY ndp.user_id
ORDER BY 個人利益 DESC
LIMIT 10;
