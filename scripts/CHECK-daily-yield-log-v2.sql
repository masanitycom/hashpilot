SELECT date, total_profit_amount, total_nft_count, profit_per_nft
FROM daily_yield_log_v2
WHERE date IN ('2026-01-01', '2026-01-02')
ORDER BY date;
