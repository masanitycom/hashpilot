-- ========================================
-- 59C23Cのavailable_usdtを修正
-- ========================================

-- 正しい計算
-- = 個人利益合計 + NFT自動付与ボーナス - 出金済み(completed)
-- = $71.93 + $1100 - $1132.01 = $39.92

SELECT '=== 修正前 ===' as section;
SELECT user_id, available_usdt FROM affiliate_cycle WHERE user_id = '59C23C';

-- 正しい値を計算して更新
UPDATE affiliate_cycle
SET available_usdt = (
  SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '59C23C'
) + (auto_nft_count * 1100) - (
  SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed'
)
WHERE user_id = '59C23C';

SELECT '=== 修正後 ===' as section;
SELECT user_id, available_usdt FROM affiliate_cycle WHERE user_id = '59C23C';
