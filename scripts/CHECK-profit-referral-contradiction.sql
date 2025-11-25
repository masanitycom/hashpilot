-- ========================================
-- トータル利益マイナスなのに紹介報酬プラスの矛盾を調査
-- ========================================

-- ========================================
-- 1. 累積利益の推移（daily_yield_log_v2）
-- ========================================
SELECT
    '累積利益の推移（最新10件）' as label,
    date,
    total_profit_amount as daily_input,
    cumulative_gross_profit as G_d,
    cumulative_fee as F_d,
    cumulative_net_profit as N_d,
    daily_pnl as delta_N_d,
    distribution_dividend as div_60pct,
    distribution_affiliate as aff_30pct,
    distribution_stock as stock_10pct
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;

-- ========================================
-- 2. 最新の累積純利益
-- ========================================
SELECT
    '最新の累積純利益' as label,
    date,
    cumulative_net_profit as N_d,
    cumulative_fee as F_d,
    cumulative_gross_profit as G_d
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 1;

-- ========================================
-- 3. 紹介報酬の合計（プラス/マイナス別）
-- ========================================
SELECT
    '紹介報酬の合計' as label,
    SUM(profit_amount) as total_referral,
    SUM(CASE WHEN profit_amount > 0 THEN profit_amount ELSE 0 END) as total_positive,
    SUM(CASE WHEN profit_amount < 0 THEN profit_amount ELSE 0 END) as total_negative,
    COUNT(*) as record_count
FROM user_referral_profit;

-- ========================================
-- 4. 日付別の紹介報酬と日利の対応
-- ========================================
SELECT
    dyl.date,
    dyl.daily_pnl as delta_N_d,
    dyl.distribution_dividend as expected_dividend,
    dyl.distribution_affiliate as expected_affiliate,
    COALESCE(SUM(urp.profit_amount), 0) as actual_referral,
    COALESCE(SUM(ndp.daily_profit), 0) as actual_dividend,
    dyl.distribution_affiliate - COALESCE(SUM(urp.profit_amount), 0) as referral_diff
FROM daily_yield_log_v2 dyl
LEFT JOIN user_referral_profit urp ON dyl.date = urp.date
LEFT JOIN nft_daily_profit ndp ON dyl.date = ndp.date
GROUP BY dyl.date, dyl.daily_pnl, dyl.distribution_dividend, dyl.distribution_affiliate
ORDER BY dyl.date DESC
LIMIT 10;

-- ========================================
-- 5. マイナス日利の日に紹介報酬が発生しているか？
-- ========================================
SELECT
    '★ マイナス日利の日の紹介報酬' as issue,
    dyl.date,
    dyl.daily_pnl as delta_N_d,
    dyl.distribution_affiliate as expected_affiliate,
    COUNT(urp.id) as referral_record_count,
    COALESCE(SUM(urp.profit_amount), 0) as actual_referral
FROM daily_yield_log_v2 dyl
LEFT JOIN user_referral_profit urp ON dyl.date = urp.date
WHERE dyl.daily_pnl < 0
GROUP BY dyl.date, dyl.daily_pnl, dyl.distribution_affiliate
HAVING COUNT(urp.id) > 0
ORDER BY dyl.date DESC;

-- ========================================
-- 6. プラス日利の日の紹介報酬
-- ========================================
SELECT
    'プラス日利の日の紹介報酬' as label,
    dyl.date,
    dyl.daily_pnl as delta_N_d,
    dyl.distribution_affiliate as expected_affiliate,
    COUNT(urp.id) as referral_record_count,
    COALESCE(SUM(urp.profit_amount), 0) as actual_referral
FROM daily_yield_log_v2 dyl
LEFT JOIN user_referral_profit urp ON dyl.date = urp.date
WHERE dyl.daily_pnl > 0
GROUP BY dyl.date, dyl.daily_pnl, dyl.distribution_affiliate
ORDER BY dyl.date DESC
LIMIT 10;

-- ========================================
-- 7. 全体の整合性チェック
-- ========================================
SELECT
    '全体の整合性チェック' as label,
    (SELECT cumulative_net_profit FROM daily_yield_log_v2 ORDER BY date DESC LIMIT 1) as latest_N_d,
    (SELECT SUM(profit_amount) FROM user_referral_profit) as total_referral,
    (SELECT SUM(daily_profit) FROM nft_daily_profit) as total_dividend,
    (SELECT SUM(stock_amount) FROM stock_fund) as total_stock;
