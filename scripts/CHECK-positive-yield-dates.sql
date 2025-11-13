-- プラスの日利データを確認
SELECT
    date,
    total_profit_amount,
    total_nft_count,
    daily_pnl,
    distribution_dividend
FROM daily_yield_log_v2
WHERE total_profit_amount > 0
ORDER BY date DESC
LIMIT 10;
