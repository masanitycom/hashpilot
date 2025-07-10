-- 日利率とNFT数の不整合を修正

-- 1. affiliate_cycleテーブルのNFT数を正しく修正
UPDATE affiliate_cycle 
SET total_nft_count = FLOOR(
    (SELECT total_purchases FROM users WHERE users.user_id = affiliate_cycle.user_id) / 1100
)
WHERE user_id IN (
    SELECT u.user_id 
    FROM users u 
    WHERE u.total_purchases > 0
    AND (
        affiliate_cycle.total_nft_count != FLOOR(u.total_purchases / 1100)
        OR affiliate_cycle.total_nft_count IS NULL
    )
);

-- 2. 2BF53Bユーザーの修正確認
SELECT 'NFT数修正後の確認' as section;
SELECT 
    u.user_id,
    u.total_purchases,
    FLOOR(u.total_purchases / 1100) as should_be_nft_count,
    ac.total_nft_count as actual_nft_count,
    CASE 
        WHEN ac.total_nft_count = FLOOR(u.total_purchases / 1100) THEN 'OK'
        ELSE 'MISMATCH'
    END as status
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id IN ('2BF53B', '9DCFD1', 'B43A3D')
ORDER BY u.total_purchases DESC;

-- 3. 日利設定を正しい値に修正（7/10のデータ）
-- 2.3%は高すぎるので1.38%に修正
UPDATE daily_yield_log 
SET 
    yield_rate = 0.0138,  -- 2.3% → 1.38%
    user_rate = 0.0138 * (1 - 0.30) * 0.6  -- 正しい計算: 0.005796
WHERE date = '2025-07-10';

-- 4. 7/10の日利データを正しい利率で再計算
DELETE FROM user_daily_profit WHERE date = '2025-07-10';

-- 5. 正しい利率で再実行
SELECT process_daily_yield_with_cycles(
    '2025-07-10'::DATE,
    0.0138,  -- 1.38%
    30,      -- 30%マージン  
    false    -- 本番モード
);

-- 6. 修正後の確認
SELECT '修正後の利益確認' as section;
SELECT 
    u.user_id,
    u.total_purchases,
    ac.total_nft_count,
    (ac.total_nft_count * 1000) as base_amount,
    udp.personal_profit,
    udp.referral_profit,
    udp.daily_profit as total_profit,
    -- 期待値計算
    (ac.total_nft_count * 1000 * 0.005796) as expected_personal_profit
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-10'
WHERE u.user_id IN ('2BF53B', '9DCFD1', 'B43A3D')
ORDER BY u.total_purchases DESC;

SELECT '修正完了: NFT数と日利率を正しい値に修正しました' as message;