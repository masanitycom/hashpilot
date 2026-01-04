-- NFT数の不一致を調査（v3）- is_pegasus_exchangeで確認

-- 1. 運用中NFT（ペガサス交換ユーザー除外）- 関数と同じ条件
SELECT
    COUNT(*) as nft_count,
    '関数と同じ条件（ペガサス交換除外）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 2. ペガサス交換ユーザーのNFT数
SELECT
    COUNT(*) as nft_count,
    'ペガサス交換ユーザー（is_pegasus_exchange = true）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND u.is_pegasus_exchange = TRUE;

-- 3. 全運用中NFT数（ペガサス含む）
SELECT
    COUNT(*) as nft_count,
    '全運用中NFT（ペガサス含む）' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02';

-- 4. daily_yield_log_v2の記録
SELECT date, total_nft_count FROM daily_yield_log_v2
WHERE date >= '2025-12-30' ORDER BY date;

-- 5. 内訳確認
SELECT
    CASE
        WHEN u.is_pegasus_exchange = TRUE THEN 'ペガサス交換'
        ELSE '通常ユーザー'
    END as user_type,
    COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
GROUP BY
    CASE
        WHEN u.is_pegasus_exchange = TRUE THEN 'ペガサス交換'
        ELSE '通常ユーザー'
    END;

-- 6. 1/2（1/1分の日利）時点での運用中NFT数詳細
SELECT
    CASE
        WHEN u.operation_start_date < '2026-01-01' THEN '12/31以前から運用中'
        WHEN u.operation_start_date = '2026-01-01' THEN '1/1から運用開始'
        WHEN u.operation_start_date = '2026-01-02' THEN '1/2から運用開始'
    END as start_period,
    CASE
        WHEN u.is_pegasus_exchange = TRUE THEN 'ペガサス'
        ELSE '通常'
    END as user_type,
    COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
GROUP BY
    CASE
        WHEN u.operation_start_date < '2026-01-01' THEN '12/31以前から運用中'
        WHEN u.operation_start_date = '2026-01-01' THEN '1/1から運用開始'
        WHEN u.operation_start_date = '2026-01-02' THEN '1/2から運用開始'
    END,
    CASE
        WHEN u.is_pegasus_exchange = TRUE THEN 'ペガサス'
        ELSE '通常'
    END
ORDER BY start_period, user_type;
