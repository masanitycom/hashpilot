-- ========================================
-- 本番環境の総投資額計算の確認
-- ========================================

-- 今日の日付
SELECT CURRENT_DATE as today;

-- ========================================
-- 1. 運用中の投資額（ペガサス除く）
-- ========================================
SELECT
    '運用中の投資額（ペガサス除く）' as category,
    COUNT(DISTINCT p.user_id) as user_count,
    COUNT(*) as purchase_count,
    SUM(p.amount_usd) as total_usdt_paid,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment_value,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft_count
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= CURRENT_DATE;

-- ========================================
-- 2. 運用開始前の投資額（ペガサス除く）
-- ========================================
SELECT
    '運用開始前の投資額（ペガサス除く）' as category,
    COUNT(DISTINCT p.user_id) as user_count,
    COUNT(*) as purchase_count,
    SUM(p.amount_usd) as total_usdt_paid,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment_value,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft_count
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
    AND (
        u.operation_start_date IS NULL
        OR u.operation_start_date > CURRENT_DATE
    );

-- ========================================
-- 3. ペガサスユーザーの投資額
-- ========================================
SELECT
    'ペガサスユーザーの投資額' as category,
    COUNT(DISTINCT p.user_id) as user_count,
    COUNT(*) as purchase_count,
    SUM(p.amount_usd) as total_usdt_paid,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment_value,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft_count
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
    AND u.is_pegasus_exchange = TRUE;

-- ========================================
-- 4. 全体サマリー
-- ========================================
SELECT
    '全体' as category,
    COUNT(DISTINCT p.user_id) as user_count,
    COUNT(*) as purchase_count,
    SUM(p.amount_usd) as total_usdt_paid,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment_value,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft_count
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true;

-- ========================================
-- 5. operation_start_dateがNULLのユーザーでNFTを持っているユーザー
-- ========================================
SELECT
    'operation_start_date=NULLでNFT保有' as issue,
    p.user_id,
    u.full_name,
    u.operation_start_date,
    u.is_pegasus_exchange,
    SUM(p.amount_usd) as total_paid,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value,
    COUNT(*) as purchase_count
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
    AND u.operation_start_date IS NULL
GROUP BY p.user_id, u.full_name, u.operation_start_date, u.is_pegasus_exchange
ORDER BY investment_value DESC;

-- ========================================
-- 6. 最近operation_start_dateが設定されたユーザー（過去7日間）
-- ========================================
SELECT
    '最近運用開始したユーザー' as category,
    u.user_id,
    u.full_name,
    u.operation_start_date,
    u.updated_at,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value
FROM users u
JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_approved = true
    AND u.operation_start_date IS NOT NULL
    AND u.updated_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY u.user_id, u.full_name, u.operation_start_date, u.updated_at
ORDER BY u.updated_at DESC;

-- ========================================
-- 7. 紹介報酬の合計（プラスかマイナスか）
-- ========================================
SELECT
    '紹介報酬の合計（全期間）' as label,
    SUM(profit_amount) as total_referral_profit,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_referral_profit;

-- 日付別の紹介報酬
SELECT
    date,
    SUM(profit_amount) as daily_referral_profit,
    COUNT(*) as record_count
FROM user_referral_profit
GROUP BY date
ORDER BY date DESC
LIMIT 10;
