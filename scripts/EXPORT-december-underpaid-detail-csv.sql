-- ========================================
-- 12月未払い紹介報酬詳細リスト（CSV出力用）
-- ========================================
-- 11月分・12月分の内訳付き

SELECT
  mw.user_id as "ユーザーID",
  u.email as "メールアドレス",
  u.coinw_uid as "CoinW_UID",
  ac.phase as "フェーズ",
  
  -- 11月紹介報酬
  COALESCE(nov.nov_referral, 0) as "11月紹介報酬",
  
  -- 12月紹介報酬（参考：1月出金で支払い予定）
  COALESCE(dec.dec_referral, 0) as "12月紹介報酬",
  
  -- 12月出金の内訳
  mw.personal_amount as "12月出金_個人利益",
  mw.referral_amount as "12月出金_紹介報酬",
  mw.total_amount as "12月出金_支払済み",
  
  -- 追加支払い必要額（11月紹介報酬のうち未払い分）
  CASE
    WHEN ac.phase = 'USDT' THEN 
      GREATEST(0, COALESCE(nov.nov_referral, 0) - COALESCE(mw.referral_amount, 0))
    ELSE 0
  END as "追加支払い額",
  
  mw.status as "ステータス"

FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id

-- 11月紹介報酬
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) nov ON mw.user_id = nov.user_id

-- 12月紹介報酬
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as dec_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-12'
  GROUP BY user_id
) dec ON mw.user_id = dec.user_id

WHERE mw.withdrawal_month = '2025-12-01'
  AND ac.phase = 'USDT'  -- USDTフェーズのみ（紹介報酬出金可能）
  AND COALESCE(nov.nov_referral, 0) > COALESCE(mw.referral_amount, 0)  -- 未払いがある

ORDER BY COALESCE(nov.nov_referral, 0) - COALESCE(mw.referral_amount, 0) DESC;
