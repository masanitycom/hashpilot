-- ========================================
-- 日利反映問題のデバッグ
-- ========================================

-- 1. 直近の日利設定を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;

-- 2. 直近のNFT日利記録を確認
SELECT
    ndp.date,
    ndp.user_id,
    ndp.nft_id,
    ndp.daily_profit,
    ndp.yield_rate,
    nm.nft_type,
    nm.nft_value,
    ndp.created_at
FROM nft_daily_profit ndp
INNER JOIN nft_master nm ON ndp.nft_id = nm.id
ORDER BY ndp.date DESC, ndp.created_at DESC
LIMIT 10;

-- 3. 特定ユーザーの運用状況を確認（運用開始済みユーザー1名）
WITH sample_user AS (
    SELECT user_id
    FROM users
    WHERE operation_start_date IS NOT NULL
      AND operation_start_date <= CURRENT_DATE
      AND has_approved_nft = true
    LIMIT 1
)
SELECT
    'ユーザー情報' as section,
    u.user_id,
    u.email,
    u.operation_start_date,
    u.has_approved_nft,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '❌ 運用待機中'
    END as status
FROM users u
WHERE u.user_id = (SELECT user_id FROM sample_user)

UNION ALL

SELECT
    'NFT保有状況' as section,
    nm.user_id,
    COUNT(*)::TEXT as nft_count,
    NULL,
    NULL,
    STRING_AGG(nm.nft_type || '($' || nm.nft_value || ')', ', ') as nft_details
FROM nft_master nm
WHERE nm.user_id = (SELECT user_id FROM sample_user)
  AND nm.buyback_date IS NULL
GROUP BY nm.user_id

UNION ALL

SELECT
    'アフィリエイトサイクル' as section,
    ac.user_id,
    ac.total_nft_count::TEXT,
    ac.available_usdt::TEXT,
    ac.cum_usdt::TEXT,
    ac.phase
FROM affiliate_cycle ac
WHERE ac.user_id = (SELECT user_id FROM sample_user)

UNION ALL

SELECT
    '直近の日利記録' as section,
    ndp.user_id,
    COUNT(*)::TEXT as profit_records,
    SUM(ndp.daily_profit)::TEXT as total_profit,
    NULL,
    MAX(ndp.date)::TEXT as latest_date
FROM nft_daily_profit ndp
WHERE ndp.user_id = (SELECT user_id FROM sample_user)
GROUP BY ndp.user_id;

-- 4. NFT別の日利記録を確認（自動付与NFTも含む）
SELECT
    nm.user_id,
    nm.id as nft_id,
    nm.nft_type,
    nm.nft_sequence,
    nm.nft_value,
    nm.acquired_date,
    COUNT(ndp.id) as profit_record_count,
    COALESCE(SUM(ndp.daily_profit), 0) as total_profit,
    MAX(ndp.date) as latest_profit_date
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.user_id IN (
    SELECT user_id
    FROM users
    WHERE operation_start_date IS NOT NULL
      AND operation_start_date <= CURRENT_DATE
      AND has_approved_nft = true
    LIMIT 3
)
AND nm.buyback_date IS NULL
GROUP BY nm.user_id, nm.id, nm.nft_type, nm.nft_sequence, nm.nft_value, nm.acquired_date
ORDER BY nm.user_id, nm.nft_sequence;

-- 5. 自動付与NFTが日利対象になっているか確認
SELECT
    'チェック: 自動付与NFTの日利対象確認' as section,
    nm.user_id,
    nm.id as nft_id,
    nm.nft_type,
    nm.acquired_date,
    u.operation_start_date,
    CASE
        WHEN nm.buyback_date IS NULL THEN '✅ 買い戻し前'
        ELSE '❌ 買い戻し済み'
    END as buyback_status,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '❌ 運用待機中'
    END as operation_status,
    COUNT(ndp.id) as profit_records
FROM nft_master nm
INNER JOIN users u ON nm.user_id = u.user_id
LEFT JOIN nft_daily_profit ndp ON nm.id = ndp.nft_id
WHERE nm.nft_type = 'auto'
GROUP BY nm.user_id, nm.id, nm.nft_type, nm.acquired_date, u.operation_start_date, nm.buyback_date
ORDER BY nm.acquired_date DESC
LIMIT 10;
