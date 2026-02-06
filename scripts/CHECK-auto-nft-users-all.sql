-- ========================================
-- NFT自動付与ユーザー全員の確認
-- ========================================

SELECT '=== NFT自動付与ユーザー一覧 ===' as section;
SELECT 
  ac.user_id,
  ac.auto_nft_count,
  ac.cum_usdt,
  ac.withdrawn_referral_usdt,
  ac.phase,
  ac.cum_usdt - ac.withdrawn_referral_usdt as 出金可能紹介報酬,
  mw.referral_amount as 一月出金紹介報酬,
  CASE 
    WHEN ac.phase = 'HOLD' THEN '❌ HOLD（紹介報酬出金不可）'
    WHEN ac.cum_usdt - ac.withdrawn_referral_usdt <= 0 THEN '❌ 出金可能額なし'
    ELSE '✓ OK'
  END as 状態
FROM affiliate_cycle ac
LEFT JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.withdrawal_month = '2026-01-01'
WHERE ac.auto_nft_count > 0
ORDER BY ac.auto_nft_count DESC, ac.cum_usdt DESC;

-- 177で始まるユーザーID
SELECT '=== 177で始まるユーザー ===' as section;
SELECT user_id, auto_nft_count, cum_usdt, phase
FROM affiliate_cycle
WHERE user_id LIKE '177%';
