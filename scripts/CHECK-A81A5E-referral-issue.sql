-- A81A5Eの紹介報酬が出金レコードに含まれない原因を調査

-- 1. monthly_referral_profitの全期間
SELECT
    year_month,
    SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE user_id = 'A81A5E'
GROUP BY year_month
ORDER BY year_month;

-- 2. 12月分の紹介報酬（A81A5E）
SELECT *
FROM monthly_referral_profit
WHERE user_id = 'A81A5E'
  AND year_month = '2025-12'
ORDER BY calculation_date;

-- 3. 11月分の紹介報酬詳細
SELECT *
FROM monthly_referral_profit
WHERE user_id = 'A81A5E'
  AND year_month = '2025-11'
ORDER BY calculation_date;

-- 4. affiliate_cycleの状態
SELECT
    user_id,
    phase,
    cum_usdt,
    available_usdt,
    withdrawn_referral_usdt
FROM affiliate_cycle
WHERE user_id = 'A81A5E';

-- 5. 紹介報酬が入っているユーザーと入っていないユーザーの比較
-- 紹介報酬が$0のユーザー数
SELECT
    COUNT(*) as zero_referral_count
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
  AND (referral_amount = 0 OR referral_amount IS NULL);

-- 6. 紹介報酬が$0以上のユーザー数
SELECT
    COUNT(*) as has_referral_count
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount > 0;

-- 7. A81A5Eと同様に11月の紹介報酬があるが12月出金に含まれていないユーザー
SELECT
    mrp.user_id,
    SUM(mrp.profit_amount) as nov_referral,
    mw.referral_amount as dec_withdrawal_referral
FROM monthly_referral_profit mrp
LEFT JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id AND mw.withdrawal_month = '2025-12-01'
WHERE mrp.year_month = '2025-11'
GROUP BY mrp.user_id, mw.referral_amount
HAVING mw.referral_amount = 0 OR mw.referral_amount IS NULL
ORDER BY SUM(mrp.profit_amount) DESC
LIMIT 20;
