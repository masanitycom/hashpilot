-- monthly_referral_profitテーブルの構造確認
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'monthly_referral_profit'
ORDER BY ordinal_position;
