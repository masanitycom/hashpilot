-- ========================================
-- 🚨 全ユーザーの7/16日利データ作成
-- 紹介報酬計算を可能にするため
-- ========================================

-- STEP 1: 現在のuser_daily_profitデータ確認
SELECT 
    '=== 📊 現在の記録状況 ===' as current_status,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users
FROM user_daily_profit
WHERE date = '2025-07-16';

-- STEP 2: 運用開始済みだが記録のないユーザーを確認
WITH recorded_users AS (
    SELECT DISTINCT user_id 
    FROM user_daily_profit 
    WHERE date = '2025-07-16'
),
operational_users AS (
    SELECT u.user_id, ac.total_nft_count
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.has_approved_nft = true 
      AND ac.total_nft_count > 0
)
SELECT 
    '=== ⚠️ 記録漏れユーザー ===' as missing_status,
    COUNT(*) as missing_count
FROM operational_users ou
WHERE ou.user_id NOT IN (SELECT user_id FROM recorded_users);

-- STEP 3: 7A9637の紹介者の記録状況確認
WITH referral_tree AS (
    -- Level1
    SELECT user_id, 1 as level, total_purchases
    FROM users 
    WHERE referrer_user_id = '7A9637'
    
    UNION
    
    -- Level2
    SELECT u2.user_id, 2 as level, u2.total_purchases
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
    
    UNION
    
    -- Level3
    SELECT u3.user_id, 3 as level, u3.total_purchases
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
)
SELECT 
    '=== 🎯 7A9637紹介者の記録状況 ===' as referral_status,
    rt.level,
    rt.user_id,
    rt.total_purchases,
    ac.total_nft_count,
    CASE 
        WHEN udp.user_id IS NOT NULL THEN 'Recorded'
        ELSE 'Missing'
    END as profit_record_status
FROM referral_tree rt
LEFT JOIN affiliate_cycle ac ON rt.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON rt.user_id = udp.user_id AND udp.date = '2025-07-16'
ORDER BY rt.level, rt.user_id;

-- STEP 4: 7/16の正確な日利設定取得
SELECT 
    '=== 📈 7/16日利設定 ===' as yield_settings,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    (yield_rate * 100) as yield_percent,
    (user_rate * 100) as user_percent
FROM daily_yield_log
WHERE date = '2025-07-16';

-- STEP 5: 全ての運用開始済みユーザーに7/16利益データを挿入
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase
)
SELECT 
    ac.user_id,
    '2025-07-16' as date,
    (ac.total_nft_count * 1000 * 0.000718) as daily_profit,
    0.001200 as yield_rate,
    0.000718 as user_rate,
    (ac.total_nft_count * 1000) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase;

-- STEP 6: 挿入後の全体確認
SELECT 
    '=== ✅ 最終確認 ===' as final_check,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(daily_profit) as total_daily_profit,
    AVG(daily_profit) as avg_profit
FROM user_daily_profit
WHERE date = '2025-07-16';

-- STEP 7: 7A9637の紹介者利益確認
SELECT 
    '=== 🎯 7A9637紹介者利益確認 ===' as referral_profits,
    user_id,
    daily_profit,
    base_amount
FROM user_daily_profit
WHERE date = '2025-07-16'
  AND user_id IN (
    -- Level1
    SELECT user_id FROM users WHERE referrer_user_id = '7A9637'
    UNION
    -- Level2  
    SELECT u2.user_id
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
    UNION
    -- Level3
    SELECT u3.user_id
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
  )
ORDER BY daily_profit DESC;

-- 完了メッセージ
SELECT 
    '🎉 全ユーザー利益データ作成完了' as status,
    '紹介報酬計算が可能になりました' as message;