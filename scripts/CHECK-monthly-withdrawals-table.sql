-- monthly_withdrawalsテーブルの内容を確認

-- 1. A81A5Eの出金レコード
SELECT *
FROM monthly_withdrawals
WHERE user_id = 'A81A5E'
ORDER BY withdrawal_month DESC;

-- 2. 12月分の出金レコード全体（personal_amount, referral_amountがある場合）
SELECT
    user_id,
    withdrawal_month,
    total_amount,
    personal_amount,
    referral_amount,
    status,
    created_at
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
ORDER BY total_amount DESC
LIMIT 20;

-- 3. 12月分の合計
SELECT
    SUM(total_amount) as total,
    SUM(personal_amount) as personal_total,
    SUM(referral_amount) as referral_total,
    COUNT(*) as record_count
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';

-- 4. monthly_withdrawalsテーブルの構造確認
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'monthly_withdrawals'
ORDER BY ordinal_position;
