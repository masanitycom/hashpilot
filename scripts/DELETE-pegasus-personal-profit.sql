-- ペガサス交換者の個人利益削除スクリプト
-- 実行前に必ずバックアップを取ること！

-- STEP 1: 削除前の確認（実行して結果を確認）
SELECT
    u.user_id,
    u.email,
    ac.available_usdt as current_available_usdt,
    COALESCE(SUM(ndp.daily_profit), 0) as personal_profit_to_remove,
    ac.available_usdt - COALESCE(SUM(ndp.daily_profit), 0) as new_available_usdt,
    COUNT(ndp.id) as profit_records_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE u.is_pegasus_exchange = TRUE
GROUP BY u.user_id, u.email, ac.available_usdt
ORDER BY u.user_id;

-- STEP 2: affiliate_cycle.available_usdtから個人利益を差し引く
UPDATE affiliate_cycle ac
SET 
    available_usdt = available_usdt - COALESCE((
        SELECT SUM(daily_profit)
        FROM nft_daily_profit ndp
        WHERE ndp.user_id = ac.user_id
    ), 0),
    updated_at = NOW()
WHERE user_id IN (
    SELECT user_id 
    FROM users 
    WHERE is_pegasus_exchange = TRUE
);

-- STEP 3: nft_daily_profitから個人利益データを削除
DELETE FROM nft_daily_profit
WHERE user_id IN (
    SELECT user_id 
    FROM users 
    WHERE is_pegasus_exchange = TRUE
);

-- STEP 4: 削除後の確認
SELECT
    u.user_id,
    u.email,
    ac.available_usdt,
    ac.cum_usdt,
    (SELECT COUNT(*) FROM nft_daily_profit WHERE user_id = u.user_id) as remaining_profit_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.is_pegasus_exchange = TRUE
ORDER BY u.user_id
LIMIT 10;
