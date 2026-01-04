-- A81A5Eの利益履歴を確認

-- 1. ユーザー情報
SELECT
    user_id,
    operation_start_date,
    is_pegasus_exchange,
    is_active_investor,
    created_at
FROM users
WHERE user_id = 'A81A5E';

-- 2. NFT情報
SELECT
    id,
    user_id,
    nft_type,
    acquired_date,
    buyback_date
FROM nft_master
WHERE user_id = 'A81A5E';

-- 3. 日利履歴（nft_daily_profit）
SELECT
    date,
    daily_profit,
    phase
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
ORDER BY date DESC
LIMIT 20;

-- 4. affiliate_cycle
SELECT *
FROM affiliate_cycle
WHERE user_id = 'A81A5E';

-- 5. 12月分の日利合計
SELECT
    SUM(daily_profit) as total_dec_profit
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
  AND date >= '2025-12-01'
  AND date <= '2025-12-31';

-- 6. 11月分の日利合計
SELECT
    SUM(daily_profit) as total_nov_profit
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30';
