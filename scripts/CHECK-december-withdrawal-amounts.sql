-- ========================================
-- 12月出金データの確認
-- ========================================

-- 上位20件の12月出金データ
SELECT '=== 12月出金データ（上位20件） ===' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status,
  ac.available_usdt
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
ORDER BY mw.total_amount DESC
LIMIT 20;

-- 合計
SELECT '=== 12月出金合計 ===' as section;
SELECT
  COUNT(*) as user_count,
  SUM(total_amount) as total,
  SUM(personal_amount) as personal_total,
  SUM(referral_amount) as referral_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
