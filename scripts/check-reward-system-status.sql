-- 報酬計算システムの現状確認
DO $$
DECLARE
    table_count INTEGER;
    function_count INTEGER;
    user_count INTEGER;
    total_investment DECIMAL;
    rec RECORD;
    referral_stats RECORD;
BEGIN
    RAISE NOTICE '=== 報酬システム状況確認 ===';
    RAISE NOTICE '実行日時: %', NOW();
    
    -- 1. テーブルの存在確認
    SELECT COUNT(*) INTO table_count FROM information_schema.tables WHERE table_name = 'users';
    RAISE NOTICE '✓ users テーブル: %', CASE WHEN table_count > 0 THEN '存在' ELSE '存在しない' END;
    
    SELECT COUNT(*) INTO table_count FROM information_schema.tables WHERE table_name = 'monthly_rewards';
    RAISE NOTICE '✓ monthly_rewards テーブル: %', CASE WHEN table_count > 0 THEN '存在' ELSE '存在しない' END;
    
    SELECT COUNT(*) INTO table_count FROM information_schema.tables WHERE table_name = 'user_daily_profit';
    RAISE NOTICE '✓ user_daily_profit テーブル: %', CASE WHEN table_count > 0 THEN '存在' ELSE '存在しない' END;
    
    -- 2. 基本統計
    SELECT COUNT(*) INTO user_count FROM users;
    SELECT COALESCE(SUM(total_purchases), 0) INTO total_investment FROM users;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== 基本統計 ===';
    RAISE NOTICE '総ユーザー数: %', user_count;
    RAISE NOTICE '総投資額: $%', total_investment;
    
    -- 3. 紹介関係の統計
    RAISE NOTICE '';
    RAISE NOTICE '=== 紹介統計 ===';
    
    -- 紹介者がいるユーザー数
    SELECT COUNT(*) INTO user_count FROM users WHERE referrer_user_id IS NOT NULL;
    RAISE NOTICE '紹介経由ユーザー数: %', user_count;
    
    -- トップ紹介者（上位5名）
    RAISE NOTICE '';
    RAISE NOTICE '=== トップ紹介者 ===';
    FOR rec IN 
        SELECT 
            u.user_id,
            u.email,
            COUNT(r.user_id) as direct_referrals,
            COALESCE(SUM(r.total_purchases), 0) as referral_investment
        FROM users u
        LEFT JOIN users r ON r.referrer_user_id = u.user_id
        GROUP BY u.user_id, u.email
        HAVING COUNT(r.user_id) > 0
        ORDER BY COUNT(r.user_id) DESC, COALESCE(SUM(r.total_purchases), 0) DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '  %: % (直接紹介: %人, 投資額: $%)', 
            rec.user_id, rec.email, rec.direct_referrals, rec.referral_investment;
    END LOOP;
    
    -- 4. 投資額別分布
    RAISE NOTICE '';
    RAISE NOTICE '=== 投資額別分布 ===';
    
    SELECT COUNT(*) INTO user_count FROM users WHERE total_purchases >= 1000;
    RAISE NOTICE '$1000以上投資者: %人', user_count;
    
    SELECT COUNT(*) INTO user_count FROM users WHERE total_purchases >= 5000;
    RAISE NOTICE '$5000以上投資者: %人', user_count;
    
    SELECT COUNT(*) INTO user_count FROM users WHERE total_purchases >= 10000;
    RAISE NOTICE '$10000以上投資者: %人', user_count;
    
    -- 5. 関数の存在確認
    RAISE NOTICE '';
    RAISE NOTICE '=== 関数確認 ===';
    
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_referral_tree') THEN
        RAISE NOTICE '✓ get_referral_tree関数: 存在';
    ELSE
        RAISE NOTICE '❌ get_referral_tree関数: 存在しない';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_user_stats') THEN
        RAISE NOTICE '✓ get_user_stats関数: 存在';
    ELSE
        RAISE NOTICE '❌ get_user_stats関数: 存在しない';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== 確認完了 ===';
    
END $$;
