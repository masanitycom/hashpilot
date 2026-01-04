-- ========================================
-- 59C23Cのavailable_usdt計算を検証
-- ========================================

-- 現在の状態
-- cum_usdt = 1330.69（紹介報酬累積）
-- withdrawn_referral_usdt = 1100.00（NFT自動付与時に受け取り済み）
-- available_usdt = -8.15
-- auto_nft_count = 1（自動NFT1個付与済み）
-- phase = HOLD（1100 <= cum_usdt < 2200）

-- 正しいavailable_usdtの計算：
-- = 個人利益合計 
-- + NFT自動付与時の受取（auto_nft_count × $1100）
-- - 出金済み（completedのみ）

SELECT '=== 正しい計算 ===' as section;
SELECT
  -- 個人利益
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '59C23C') as personal_profit,
  
  -- NFT自動付与時の受取（1100 × auto_nft_count）
  (SELECT auto_nft_count * 1100 FROM affiliate_cycle WHERE user_id = '59C23C') as nft_bonus,
  
  -- 出金済み（completed）
  (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed') as withdrawn_completed,
  
  -- 現在のavailable_usdt
  (SELECT available_usdt FROM affiliate_cycle WHERE user_id = '59C23C') as current_available,
  
  -- 正しいavailable_usdt
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '59C23C')
  + (SELECT auto_nft_count * 1100 FROM affiliate_cycle WHERE user_id = '59C23C')
  - (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed')
  as correct_available;

-- 12月出金のステータス
SELECT '=== 12月出金のステータス ===' as section;
SELECT withdrawal_month, total_amount, status
FROM monthly_withdrawals
WHERE user_id = '59C23C';
