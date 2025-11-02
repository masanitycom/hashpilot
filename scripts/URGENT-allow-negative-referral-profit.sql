-- 紹介報酬のマイナス値を許可（チェック制約を削除）
-- 問題: profit_amount >= 0 の制約があり、マイナス日利時にエラー

-- 制約名を確認
SELECT
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'user_referral_profit'::regclass
AND contype = 'c';

-- profit_amountのチェック制約を削除
ALTER TABLE user_referral_profit
DROP CONSTRAINT IF EXISTS user_referral_profit_profit_amount_check;

-- nft_daily_profitのチェック制約も確認・削除
SELECT
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'nft_daily_profit'::regclass
AND contype = 'c';

ALTER TABLE nft_daily_profit
DROP CONSTRAINT IF EXISTS nft_daily_profit_daily_profit_check;

SELECT '✅ マイナス値を許可しました' as status;
