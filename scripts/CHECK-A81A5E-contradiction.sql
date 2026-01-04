-- A81A5Eの矛盾を調査

-- 1. nft_daily_profitの全履歴（日付フィルタなし）
SELECT '=== nft_daily_profit 全履歴 ===' as section;
SELECT user_id, date, daily_profit, created_at
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
ORDER BY date;

-- 2. monthly_withdrawalsの全履歴
SELECT '=== monthly_withdrawals 全履歴 ===' as section;
SELECT user_id, withdrawal_month, total_amount, personal_amount, referral_amount, status, created_at
FROM monthly_withdrawals
WHERE user_id = 'A81A5E'
ORDER BY withdrawal_month;

-- 3. 12月分のnft_daily_profitの合計
SELECT '=== 12月分nft_daily_profit合計 ===' as section;
SELECT user_id, SUM(daily_profit) as dec_total
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
  AND date >= '2025-12-01' AND date < '2026-01-01'
GROUP BY user_id;

-- 4. users テーブルの情報
SELECT '=== users テーブル ===' as section;
SELECT user_id, operation_start_date, has_approved_nft, is_pegasus_exchange, updated_at
FROM users
WHERE user_id = 'A81A5E';

-- 5. nft_master テーブル
SELECT '=== nft_master テーブル ===' as section;
SELECT id, user_id, nft_type, acquired_date, buyback_date, created_at
FROM nft_master
WHERE user_id = 'A81A5E'
ORDER BY acquired_date;
