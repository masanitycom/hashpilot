-- ========================================
-- マイナスavailable_usdtのユーザーを修正
-- ========================================

-- ========================================
-- 59C23Cの確認と修正
-- ========================================
SELECT '=== 59C23C 計算 ===' as section;
SELECT
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '59C23C') as personal_profit,
  (SELECT auto_nft_count FROM affiliate_cycle WHERE user_id = '59C23C') as auto_nft,
  (SELECT auto_nft_count * 1100 FROM affiliate_cycle WHERE user_id = '59C23C') as nft_bonus,
  (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed') as withdrawn,
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '59C23C')
  + (SELECT auto_nft_count * 1100 FROM affiliate_cycle WHERE user_id = '59C23C')
  - (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '59C23C' AND status = 'completed')
  as correct_available;

-- ========================================
-- 177B83の確認と修正
-- ========================================
SELECT '=== 177B83 計算 ===' as section;
SELECT
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '177B83') as personal_profit,
  (SELECT auto_nft_count FROM affiliate_cycle WHERE user_id = '177B83') as auto_nft,
  (SELECT auto_nft_count * 1100 FROM affiliate_cycle WHERE user_id = '177B83') as nft_bonus,
  (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '177B83' AND status = 'completed') as withdrawn,
  (SELECT COALESCE(SUM(daily_profit), 0) FROM nft_daily_profit WHERE user_id = '177B83')
  + (SELECT auto_nft_count * 1100 FROM affiliate_cycle WHERE user_id = '177B83')
  - (SELECT COALESCE(SUM(total_amount), 0) FROM monthly_withdrawals WHERE user_id = '177B83' AND status = 'completed')
  as correct_available;

-- ========================================
-- 両方を修正
-- ========================================
SELECT '=== 修正実行 ===' as section;

UPDATE affiliate_cycle ac
SET available_usdt = sub.correct_available
FROM (
  SELECT
    ac2.user_id,
    COALESCE(ndp.personal_total, 0) + (ac2.auto_nft_count * 1100) - COALESCE(mw.withdrawn, 0) as correct_available
  FROM affiliate_cycle ac2
  LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as personal_total
    FROM nft_daily_profit
    GROUP BY user_id
  ) ndp ON ac2.user_id = ndp.user_id
  LEFT JOIN (
    SELECT user_id, SUM(total_amount) as withdrawn
    FROM monthly_withdrawals
    WHERE status = 'completed'
    GROUP BY user_id
  ) mw ON ac2.user_id = mw.user_id
  WHERE ac2.user_id IN ('59C23C', '177B83')
) sub
WHERE ac.user_id = sub.user_id;

-- ========================================
-- 修正後確認
-- ========================================
SELECT '=== 修正後 ===' as section;
SELECT user_id, available_usdt, cum_usdt, phase, auto_nft_count
FROM affiliate_cycle
WHERE user_id IN ('59C23C', '177B83');
