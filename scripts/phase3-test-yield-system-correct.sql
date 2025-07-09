-- Phase 3: 日利システムのテスト

-- 1. 現在のテーブル状況を確認
SELECT 'daily_yield_log table check' as test_step;
SELECT COUNT(*) as daily_yield_log_count FROM daily_yield_log;

SELECT 'user_daily_profit table check' as test_step;
SELECT COUNT(*) as user_daily_profit_count FROM user_daily_profit;

SELECT 'company_daily_profit table check' as test_step;
SELECT COUNT(*) as company_daily_profit_count FROM company_daily_profit;

-- 2. テーブル構造を確認
SELECT 'user_daily_profit table structure' as test_step;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit' 
ORDER BY ordinal_position;

-- 3. テストデータの準備
DO $$
BEGIN
    RAISE NOTICE '=== Phase 3: 日利システムテスト開始 ===';
END;
$$;

-- 4. purchasesテーブルの構造確認
SELECT 'purchases table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- 5. usersテーブルとpurchasesテーブルの型確認
SELECT 'users.id data type:' as info;
SELECT data_type FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'id';

SELECT 'purchases.user_id data type:' as info;
SELECT data_type FROM information_schema.columns 
WHERE table_name = 'purchases' AND column_name = 'user_id';

-- 6. 実際のpurchasesデータを確認
SELECT 'Sample purchases data:' as info;
SELECT * FROM purchases LIMIT 3;

-- 7. アクティブユーザーと購入データを確認
SELECT 'Active users with NFT approval' as test_step;
SELECT 
    u.id,
    u.email,
    u.is_active,
    u.has_approved_nft,
    COALESCE(SUM(p.amount_usd::DECIMAL(15,2)), 0) as total_investment
FROM users u
LEFT JOIN purchases p ON u.id::TEXT = p.user_id::TEXT 
    AND p.payment_status = 'approved' 
    AND p.admin_approved = TRUE
WHERE u.is_active = TRUE 
AND u.has_approved_nft = TRUE
GROUP BY u.id, u.email, u.is_active, u.has_approved_nft
ORDER BY u.email;

-- 8. 管理者権限の確認
SELECT 'Admin users:' as info;
SELECT email, is_active, created_at FROM admins WHERE is_active = TRUE;

-- 9. テスト用日利投稿（今日の日付で1%日利、30%マージン）
SELECT 'Testing yield posting' as test_step;
SELECT admin_post_yield(
    CURRENT_DATE,
    0.01,  -- 1% yield rate
    0.30,  -- 30% margin rate
    FALSE  -- not month end
) as yield_result;

-- 10. 投稿結果を確認
SELECT 'Checking daily_yield_log after posting' as test_step;
SELECT * FROM daily_yield_log ORDER BY created_at DESC LIMIT 1;

SELECT 'Checking user_daily_profit after posting' as test_step;
SELECT 
    udp.*,
    u.email
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.id
WHERE udp.date = CURRENT_DATE
ORDER BY udp.created_at DESC;

SELECT 'Checking company_daily_profit after posting' as test_step;
SELECT * FROM company_daily_profit WHERE date = CURRENT_DATE;

-- 11. 統計情報を表示
SELECT 'System statistics' as test_step;
SELECT 
    COUNT(DISTINCT u.id) as total_active_users,
    COALESCE(SUM(p.amount_usd::DECIMAL(15,2)), 0) as total_investments,
    COALESCE(AVG(p.amount_usd::DECIMAL(15,2)), 0) as avg_investment
FROM users u
LEFT JOIN purchases p ON u.id::TEXT = p.user_id::TEXT 
    AND p.payment_status = 'approved' 
    AND p.admin_approved = TRUE
WHERE u.is_active = TRUE 
AND u.has_approved_nft = TRUE;

DO $$
BEGIN
    RAISE NOTICE '=== Phase 3: 日利システムテスト完了 ===';
    RAISE NOTICE '管理画面 /admin/yield にアクセスして日利投稿をテストしてください';
END;
$$;
