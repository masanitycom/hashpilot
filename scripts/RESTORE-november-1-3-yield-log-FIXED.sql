-- ========================================
-- 11月1日～3日の日利率を逆算
-- ========================================

SELECT
    udp.date,
    SUM(udp.daily_profit) as total_profit,
    COUNT(DISTINCT udp.user_id) as user_count,
    -- 運用中のNFT総数（簡易計算: ユーザー数 × 平均NFT数）
    -- 実際には各日付時点のNFT数を計算する必要がある
    254 as estimated_nft_count,
    254 * 1000 as estimated_investment,
    -- ユーザー利率 = 配布額 / 総投資額
    ROUND((SUM(udp.daily_profit) / (254.0 * 1000)) * 100, 6) as calculated_user_rate,
    -- 日利率を逆算: user_rate = yield_rate × 0.7 × 0.6
    -- yield_rate = user_rate / 0.42
    ROUND((SUM(udp.daily_profit) / (254.0 * 1000) / 0.42) * 100, 6) as calculated_yield_rate,
    0.30 as margin_rate
FROM user_daily_profit udp
WHERE udp.date >= '2025-11-01' AND udp.date <= '2025-11-03'
GROUP BY udp.date
ORDER BY udp.date;
