-- 現在（2026-01-03）時点で運用中のNFT数を計算

-- 1. 運用中NFT数（operation_start_date <= 今日）
SELECT
    COUNT(*) as operational_nft_count,
    '2026-01-03時点' as description
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-03';

-- 2. 運用開始日ごとのNFT数サマリー
SELECT
    CASE
        WHEN u.operation_start_date <= '2026-01-03' THEN '運用中'
        ELSE '運用開始前'
    END as status,
    COUNT(*) as nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
GROUP BY
    CASE
        WHEN u.operation_start_date <= '2026-01-03' THEN '運用中'
        ELSE '運用開始前'
    END;

-- 3. daily_yield_log_v2の最新データ
SELECT *
FROM daily_yield_log_v2
ORDER BY id DESC
LIMIT 5;

-- 4. 2026-01-15運用開始のユーザー詳細（運用開始前）
SELECT
    u.user_id,
    u.operation_start_date,
    nm.acquired_date,
    nm.nft_type
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2026-01-15'
  AND nm.buyback_date IS NULL
ORDER BY nm.acquired_date;

-- 5. 2026-01-01運用開始のユーザー詳細（運用中）
SELECT
    u.user_id,
    u.operation_start_date,
    nm.acquired_date,
    nm.nft_type
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.operation_start_date = '2026-01-01'
  AND nm.buyback_date IS NULL
ORDER BY nm.acquired_date;
