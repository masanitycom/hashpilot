-- ========================================
-- NFTサイクル全体分析
-- ========================================

-- 1. 自動NFT付与ユーザー全員の状況
SELECT '=== 1. 自動NFT付与ユーザー ===' as section;
SELECT 
  ac.user_id,
  ac.auto_nft_count,
  ac.manual_nft_count,
  ac.cum_usdt,
  ac.available_usdt,
  ac.withdrawn_referral_usdt,
  ac.phase,
  COALESCE(mrp.total_referral, 0) as total_referral_earned,
  COALESCE(mrp.total_referral, 0) - COALESCE(ac.withdrawn_referral_usdt, 0) as referral_balance
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.auto_nft_count DESC;

-- 2. cum_usdt >= 2200 で未付与のユーザーがいないか
SELECT '=== 2. cum_usdt >= 2200 のユーザー（NFT付与漏れ確認）===' as section;
SELECT 
  ac.user_id,
  ac.cum_usdt,
  ac.auto_nft_count,
  ac.phase
FROM affiliate_cycle ac
WHERE ac.cum_usdt >= 2200;

-- 3. 全ユーザーのcum_usdtとphaseの整合性確認
SELECT '=== 3. フェーズ不整合ユーザー ===' as section;
SELECT 
  user_id,
  cum_usdt,
  phase,
  CASE 
    WHEN cum_usdt < 1100 THEN 'USDT'
    WHEN cum_usdt >= 1100 AND cum_usdt < 2200 THEN 'HOLD'
    ELSE 'NFT付与すべき'
  END as expected_phase
FROM affiliate_cycle
WHERE phase != CASE 
    WHEN cum_usdt < 1100 THEN 'USDT'
    WHEN cum_usdt >= 1100 AND cum_usdt < 2200 THEN 'HOLD'
    ELSE phase
  END
  OR cum_usdt >= 2200;

-- 4. available_usdtがマイナスのユーザー
SELECT '=== 4. available_usdtがマイナスのユーザー ===' as section;
SELECT 
  user_id,
  available_usdt,
  cum_usdt,
  phase
FROM affiliate_cycle
WHERE available_usdt < 0;

-- 5. 59C23Cの詳細
SELECT '=== 5. 59C23C 詳細 ===' as section;
SELECT 
  ac.*
FROM affiliate_cycle ac
WHERE ac.user_id = '59C23C';

-- 6. 59C23Cの月別紹介報酬
SELECT '=== 6. 59C23C 月別紹介報酬 ===' as section;
SELECT 
  year_month,
  SUM(profit_amount) as monthly_total
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY year_month
ORDER BY year_month;

-- 7. 59C23Cの出金履歴
SELECT '=== 7. 59C23C 出金履歴 ===' as section;
SELECT 
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY withdrawal_month;
