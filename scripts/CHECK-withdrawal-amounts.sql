-- 出金履歴のpersonal_amount, referral_amountを確認

-- 11月分の出金履歴
SELECT '【11月分出金履歴】' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  withdrawal_month
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
ORDER BY total_amount DESC
LIMIT 20;

-- カラムが存在するか確認
SELECT '【monthly_withdrawalsテーブル構造】' as section;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'monthly_withdrawals'
ORDER BY ordinal_position;

-- affiliate_cycleのwithdrawn_referral_usdt確認
SELECT '【affiliate_cycle withdrawn_referral_usdt】' as section;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'affiliate_cycle'
  AND column_name = 'withdrawn_referral_usdt';
