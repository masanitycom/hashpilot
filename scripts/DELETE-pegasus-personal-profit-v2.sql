-- ペガサス交換者の個人利益削除スクリプト（修正版）
-- 実行前に必ずバックアップを取ること！

-- STEP 1: 削除前の確認（実行して結果を確認）
SELECT
    u.user_id,
    u.email,
    ac.available_usdt as current_available_usdt,
    COALESCE((SELECT SUM(daily_profit) FROM nft_daily_profit WHERE user_id = u.user_id), 0) as personal_profit,
    ac.cum_usdt as referral_profit,
    COUNT(ndp.id) as profit_records_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE u.is_pegasus_exchange = TRUE
GROUP BY u.user_id, u.email, ac.available_usdt, ac.cum_usdt
ORDER BY u.user_id;

-- STEP 2: nft_daily_profitから個人利益データを削除
DELETE FROM nft_daily_profit
WHERE user_id IN (
    SELECT user_id 
    FROM users 
    WHERE is_pegasus_exchange = TRUE
);

-- STEP 3: affiliate_cycle.available_usdtを0にリセット
-- （個人利益を削除したので、available_usdtも0にする）
UPDATE affiliate_cycle
SET 
    available_usdt = 0,
    updated_at = NOW()
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

-- STEP 5: 全体の確認（全65名）
SELECT
    COUNT(*) as total_pegasus_users,
    SUM(CASE WHEN ac.available_usdt = 0 THEN 1 ELSE 0 END) as users_with_zero_available,
    SUM(CASE WHEN (SELECT COUNT(*) FROM nft_daily_profit WHERE user_id = u.user_id) = 0 THEN 1 ELSE 0 END) as users_with_no_profit
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.is_pegasus_exchange = TRUE;
