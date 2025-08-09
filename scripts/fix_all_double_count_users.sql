-- ========================================
-- 全ての二重カウント問題を修正
-- 影響ユーザー: 356B74, 9E6DA5, A81A5E
-- ========================================

BEGIN;

-- 1. 修正前の状態を記録
SELECT 'BEFORE FIX - Current State' as status;
SELECT u.user_id, u.email, 
       u.total_purchases as current_amount,
       ac.total_nft_count as current_nft,
       p.actual_amount,
       p.actual_nft
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN (
    SELECT user_id, 
           SUM(amount_usd) as actual_amount,
           SUM(nft_quantity) as actual_nft
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.user_id IN ('356B74', '9E6DA5', 'A81A5E')
ORDER BY u.user_id;

-- 2. ユーザー 356B74 (ck73967396@gmail.com) の修正
UPDATE users 
SET total_purchases = 1100.00,
    updated_at = NOW()
WHERE user_id = '356B74';

UPDATE affiliate_cycle 
SET total_nft_count = 1,
    manual_nft_count = 1,
    auto_nft_count = 0,
    updated_at = NOW()
WHERE user_id = '356B74';

-- 3. ユーザー 9E6DA5 (miina19580106@gmail.com) の修正
UPDATE users 
SET total_purchases = 11000.00,
    updated_at = NOW()
WHERE user_id = '9E6DA5';

UPDATE affiliate_cycle 
SET total_nft_count = 10,
    manual_nft_count = 10,
    auto_nft_count = 0,
    updated_at = NOW()
WHERE user_id = '9E6DA5';

-- 4. ユーザー A81A5E (sakanatsuri303@gmail.com) の修正
UPDATE users 
SET total_purchases = 1100.00,
    updated_at = NOW()
WHERE user_id = 'A81A5E';

UPDATE affiliate_cycle 
SET total_nft_count = 1,
    manual_nft_count = 1,
    auto_nft_count = 0,
    updated_at = NOW()
WHERE user_id = 'A81A5E';

-- 5. 修正後の確認
SELECT 'AFTER FIX - Updated State' as status;
SELECT u.user_id, u.email, 
       u.total_purchases as fixed_amount,
       ac.total_nft_count as fixed_nft,
       p.actual_amount,
       p.actual_nft,
       CASE 
           WHEN u.total_purchases = p.actual_amount AND ac.total_nft_count = p.actual_nft THEN '✅ 修正完了'
           ELSE '❌ エラー'
       END as status
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN (
    SELECT user_id, 
           SUM(amount_usd) as actual_amount,
           SUM(nft_quantity) as actual_nft
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.user_id IN ('356B74', '9E6DA5', 'A81A5E', '870323')
ORDER BY u.user_id;

-- 6. 利益計算への影響を確認
SELECT 'Profit Impact Check' as status;
SELECT user_id, 
       COUNT(*) as profit_days,
       SUM(personal_profit) as total_personal_profit,
       MAX(date) as latest_date
FROM user_daily_profit
WHERE user_id IN ('356B74', '9E6DA5', 'A81A5E', '870323')
GROUP BY user_id
ORDER BY user_id;

COMMIT;

-- 7. 今後の重複を防ぐためのチェック
SELECT 'Prevention Check - Find Pattern' as status;
SELECT 
    COUNT(*) as affected_users,
    'Multiple count issue detected' as issue_type,
    STRING_AGG(user_id || ' (' || email || ')', ', ') as affected_user_list
FROM (
    SELECT u.user_id, u.email
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    LEFT JOIN (
        SELECT user_id, 
               SUM(amount_usd) as actual_amount,
               SUM(nft_quantity) as actual_nft
        FROM purchases
        WHERE admin_approved = true
        GROUP BY user_id
    ) p ON u.user_id = p.user_id
    WHERE u.has_approved_nft = true
      AND (u.total_purchases != COALESCE(p.actual_amount, 0) 
           OR ac.total_nft_count != COALESCE(p.actual_nft, 0))
) as problem_users;

SELECT 'All fixes completed successfully!' as final_status;