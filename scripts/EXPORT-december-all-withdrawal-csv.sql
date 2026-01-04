-- ========================================
-- 12月出金全データ詳細CSV
-- ========================================

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
  mw.personal_amount as "個人利益",
  mw.referral_amount as "紹介報酬_記録",
  mw.total_amount as "出金額",
  
  -- 内訳合計と出金額の差
  (COALESCE(mw.personal_amount, 0) + COALESCE(mw.referral_amount, 0)) as "内訳合計",
  mw.total_amount - (COALESCE(mw.personal_amount, 0) + COALESCE(mw.referral_amount, 0)) as "差額",
  
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
ORDER BY mw.total_amount DESC;
