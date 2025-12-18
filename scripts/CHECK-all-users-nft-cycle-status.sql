-- ========================================
-- 全ユーザーのNFTサイクル状況確認
-- HOLDフェーズで紹介報酬を出金したユーザーを特定
-- ========================================

-- 1. HOLDフェーズのユーザー一覧
SELECT '【1】HOLDフェーズのユーザー' as section;
SELECT
  ac.user_id,
  ac.phase,
  ac.cum_usdt,
  ac.available_usdt,
  ac.withdrawn_referral_usdt,
  mw.referral_amount as 出金記録の紹介報酬,
  CASE
    WHEN ac.cum_usdt >= 1100 THEN
      -- HOLDフェーズの場合、最初の$1100のみ出金可能
      LEAST(ac.cum_usdt, 1100)
    ELSE
      ac.cum_usdt
  END as 本来出金可能な紹介報酬,
  mw.referral_amount - CASE
    WHEN ac.cum_usdt >= 1100 THEN LEAST(ac.cum_usdt, 1100)
    ELSE ac.cum_usdt
  END as 差額
FROM affiliate_cycle ac
LEFT JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.withdrawal_month = '2025-11-01'
WHERE ac.phase = 'HOLD'
  AND mw.referral_amount > 0
ORDER BY ac.cum_usdt DESC;

-- 2. cum_usdt >= 1100 のユーザー（HOLDフェーズに入っているはず）
SELECT '【2】紹介報酬$1100以上のユーザー' as section;
SELECT
  ac.user_id,
  ac.phase,
  ac.cum_usdt,
  ac.withdrawn_referral_usdt,
  mw.referral_amount as 出金記録の紹介報酬,
  mw.total_amount as 出金合計,
  mw.status
FROM affiliate_cycle ac
LEFT JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.withdrawal_month = '2025-11-01'
WHERE ac.cum_usdt >= 1100
ORDER BY ac.cum_usdt DESC;

-- 3. 59C23CのNFT保有状況
SELECT '【3】59C23CのNFT保有状況' as section;
SELECT
  user_id,
  id as nft_id,
  nft_type,
  acquired_date,
  buyback_date
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY acquired_date;

-- 4. 59C23Cの購入履歴
SELECT '【4】59C23Cの購入履歴' as section;
SELECT
  user_id,
  id,
  amount_usd,
  admin_approved,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id = '59C23C'
ORDER BY created_at;
