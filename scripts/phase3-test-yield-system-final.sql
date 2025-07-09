-- Phase 3: 日利システムの最終テスト

DO $$
BEGIN
    RAISE NOTICE '=== Phase 3: 日利システムテスト開始 ===';
END;
$$;

-- 1. テーブル構造を確認
SELECT 'user_daily_profit table structure' as test_step;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit' 
ORDER BY ordinal_position;

SELECT 'daily_yield_log table structure' as test_step;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
ORDER BY ordinal_position;

SELECT 'company_daily_profit table structure' as test_step;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'company_daily_profit' 
ORDER BY ordinal_position;

-- 2. アクティブユーザーと購入データを確認
SELECT 'Active users with NFT approval and purchases' as test_step;
SELECT 
    u.id,
    u.email,
    u.is_active,
    u.has_approved_nft,
    COALESCE(SUM(p.amount_usd::DECIMAL(15,2)), 1000.00) as total_investment
FROM users u
LEFT JOIN purchases p ON u.id::TEXT = p.user_id::TEXT 
    AND p.payment_status = 'approved' 
    AND p.admin_approved = TRUE
WHERE u.is_active = TRUE 
AND u.has_approved_nft = TRUE
GROUP BY u.id, u.email, u.is_active, u.has_approved_nft
ORDER BY u.email
LIMIT 5;

-- 3. 管理者権限の確認
SELECT 'Admin users' as test_step;
SELECT email, is_active, created_at FROM admins WHERE is_active = TRUE;

-- 4. テスト用日利投稿（今日の日付で1%日利、30%マージン）
SELECT 'Testing yield posting for today' as test_step;
SELECT admin_post_yield(
    CURRENT_DATE,
    0.01,  -- 1% yield rate
    0.30,  -- 30% margin rate
    FALSE  -- not month end
) as yield_result;

-- 5. 投稿結果を確認
SELECT 'Checking daily_yield_log after posting' as test_step;
SELECT * FROM daily_yield_log WHERE date = CURRENT_DATE;

SELECT 'Checking user_daily_profit after posting' as test_step;
SELECT * FROM user_daily_profit WHERE date = CURRENT_DATE ORDER BY created_at DESC;

SELECT 'Checking company_daily_profit after posting' as test_step;
SELECT * FROM company_daily_profit WHERE date = CURRENT_DATE;

-- 6. 統計情報を表示
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
