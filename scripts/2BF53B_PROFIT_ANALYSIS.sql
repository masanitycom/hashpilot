-- 🔍 2BF53B利益問題の根本原因分析
-- 2025年1月16日

-- ===== 問題の整理 =====
-- 2BF53B: 承認日 2025-06-17 → 運用開始 2025-07-02 → 現在利益 $1.25
-- 期待される利益: 1NFT × 1000ドル × 1.5% × 0.6 × 14日間 = $126
-- 実際の利益: $1.25
-- 差額: $124.75 (99%の利益が不足)

-- 1. 2BF53Bの利益記録詳細（日別）
SELECT 
    '2BF53B日別利益記録' as analysis_type,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '2BF53B'
ORDER BY date;

-- 2. 2BF53Bの利益計算が正しいかチェック
WITH expected_profit AS (
    SELECT 
        udp.date,
        udp.daily_profit as actual_profit,
        -- 期待される利益計算: NFT数 × 1000 × ユーザー受取率
        (ac.total_nft_count * 1000 * udp.user_rate) as expected_profit,
        udp.daily_profit - (ac.total_nft_count * 1000 * udp.user_rate) as difference
    FROM user_daily_profit udp
    JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
    WHERE udp.user_id = '2BF53B'
)
SELECT 
    '利益計算検証' as analysis_type,
    date,
    actual_profit,
    expected_profit,
    difference,
    CASE 
        WHEN ABS(difference) < 0.01 THEN '正常'
        ELSE '🚨異常'
    END as status
FROM expected_profit
ORDER BY date;

-- 3. 2BF53Bの運用期間中の日利設定確認
SELECT 
    '日利設定確認' as analysis_type,
    dyl.date,
    dyl.yield_rate,
    dyl.margin_rate,
    dyl.user_rate,
    CASE 
        WHEN udp.user_id IS NOT NULL THEN '利益あり'
        ELSE '利益なし'
    END as profit_status
FROM daily_yield_log dyl
LEFT JOIN user_daily_profit udp ON dyl.date = udp.date AND udp.user_id = '2BF53B'
WHERE dyl.date >= '2025-07-02' -- 運用開始日以降
ORDER BY dyl.date;

-- 4. 運用期間中なのに利益がない日の特定
SELECT 
    '利益欠損日特定' as analysis_type,
    dyl.date as missing_date,
    dyl.yield_rate,
    dyl.user_rate,
    '利益記録なし' as issue
FROM daily_yield_log dyl
WHERE dyl.date >= '2025-07-02'
AND dyl.date <= CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM user_daily_profit udp 
    WHERE udp.user_id = '2BF53B' AND udp.date = dyl.date
)
ORDER BY dyl.date;

-- 5. 2BF53Bと同じ1NFTユーザーとの比較
SELECT 
    '同NFT数ユーザー比較' as analysis_type,
    u.user_id,
    u.email,
    ac.total_nft_count,
    ac.cum_usdt,
    COUNT(udp.date) as profit_days,
    MIN(p.admin_approved_at)::date as approval_date,
    MIN(p.admin_approved_at)::date + 15 as operation_start_date
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE ac.total_nft_count = 1 -- 2BF53Bと同じ1NFT
AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, ac.total_nft_count, ac.cum_usdt
ORDER BY ac.cum_usdt DESC;

-- 6. システムログから2BF53B関連のエラー確認
SELECT 
    'システムログ確認' as analysis_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE user_id = '2BF53B'
OR message LIKE '%2BF53B%'
OR details::text LIKE '%2BF53B%'
ORDER BY created_at DESC;

-- 7. 修正が必要な利益日数の計算
WITH missing_days AS (
    SELECT COUNT(*) as missing_count
    FROM daily_yield_log dyl
    WHERE dyl.date >= '2025-07-02'
    AND dyl.date <= CURRENT_DATE
    AND NOT EXISTS (
        SELECT 1 FROM user_daily_profit udp 
        WHERE udp.user_id = '2BF53B' AND udp.date = dyl.date
    )
),
expected_total AS (
    SELECT 
        md.missing_count,
        ROUND(md.missing_count * 1 * 1000 * 0.009, 2) as missing_profit_amount
    FROM missing_days md
)
SELECT 
    '修正必要額計算' as analysis_type,
    missing_count as missing_days,
    missing_profit_amount as missing_profit_usd,
    1.25 as current_profit,
    1.25 + missing_profit_amount as expected_profit_after_fix
FROM expected_total;