-- 完全なデータベース構造確認（本番環境用）
DO $$
DECLARE
    rec RECORD;
    table_count INTEGER;
    column_info TEXT;
BEGIN
    RAISE NOTICE '=== HASH PILOT データベース完全監査 ===';
    RAISE NOTICE '実行日時: %', NOW();
    
    -- 1. 全テーブル一覧
    RAISE NOTICE '';
    RAISE NOTICE '=== 既存テーブル一覧 ===';
    FOR rec IN 
        SELECT table_name, table_type 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name
    LOOP
        SELECT COUNT(*) INTO table_count FROM information_schema.columns 
        WHERE table_name = rec.table_name AND table_schema = 'public';
        
        RAISE NOTICE '✓ % (%) - %列', rec.table_name, rec.table_type, table_count;
    END LOOP;
    
    -- 2. users テーブル詳細
    RAISE NOTICE '';
    RAISE NOTICE '=== users テーブル構造 ===';
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        FOR rec IN 
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = 'users' AND table_schema = 'public'
            ORDER BY ordinal_position
        LOOP
            RAISE NOTICE '  - %: % (NULL: %) DEFAULT: %', 
                rec.column_name, rec.data_type, rec.is_nullable, COALESCE(rec.column_default, 'なし');
        END LOOP;
        
        -- users テーブルのレコード数とサンプル
        SELECT COUNT(*) INTO table_count FROM users;
        RAISE NOTICE '  レコード数: %', table_count;
        
        IF table_count > 0 THEN
            RAISE NOTICE '  サンプルデータ（最新5件）:';
            FOR rec IN 
                SELECT user_id, email, total_purchases, referrer_user_id, created_at::DATE
                FROM users 
                ORDER BY created_at DESC 
                LIMIT 5
            LOOP
                RAISE NOTICE '    ID:% Email:% 投資額:$% 紹介者:% 登録日:%', 
                    rec.user_id, rec.email, COALESCE(rec.total_purchases, 0), 
                    COALESCE(rec.referrer_user_id, 'なし'), rec.created_at;
            END LOOP;
        END IF;
    ELSE
        RAISE NOTICE '  ❌ users テーブルが存在しません';
    END IF;
    
    -- 3. purchases テーブル詳細
    RAISE NOTICE '';
    RAISE NOTICE '=== purchases テーブル構造 ===';
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'purchases') THEN
        FOR rec IN 
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = 'purchases' AND table_schema = 'public'
            ORDER BY ordinal_position
        LOOP
            RAISE NOTICE '  - %: % (NULL: %) DEFAULT: %', 
                rec.column_name, rec.data_type, rec.is_nullable, COALESCE(rec.column_default, 'なし');
        END LOOP;
        
        SELECT COUNT(*) INTO table_count FROM purchases;
        RAISE NOTICE '  レコード数: %', table_count;
    ELSE
        RAISE NOTICE '  ❌ purchases テーブルが存在しません';
    END IF;
    
    -- 4. admins テーブル詳細
    RAISE NOTICE '';
    RAISE NOTICE '=== admins テーブル構造 ===';
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admins') THEN
        FOR rec IN 
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = 'admins' AND table_schema = 'public'
            ORDER BY ordinal_position
        LOOP
            RAISE NOTICE '  - %: % (NULL: %) DEFAULT: %', 
                rec.column_name, rec.data_type, rec.is_nullable, COALESCE(rec.column_default, 'なし');
        END LOOP;
        
        SELECT COUNT(*) INTO table_count FROM admins;
        RAISE NOTICE '  レコード数: %', table_count;
    ELSE
        RAISE NOTICE '  ❌ admins テーブルが存在しません';
    END IF;
    
    -- 5. 関数一覧
    RAISE NOTICE '';
    RAISE NOTICE '=== 既存関数一覧 ===';
    FOR rec IN 
        SELECT routine_name, routine_type, data_type
        FROM information_schema.routines 
        WHERE routine_schema = 'public'
        ORDER BY routine_name
    LOOP
        RAISE NOTICE '✓ %() - % returns %', rec.routine_name, rec.routine_type, COALESCE(rec.data_type, 'void');
    END LOOP;
    
    -- 6. RLS ポリシー確認
    RAISE NOTICE '';
    RAISE NOTICE '=== RLS ポリシー確認 ===';
    FOR rec IN 
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
        FROM pg_policies 
        WHERE schemaname = 'public'
        ORDER BY tablename, policyname
    LOOP
        RAISE NOTICE '✓ %.%: % (%) for %', 
            rec.schemaname, rec.tablename, rec.policyname, rec.cmd, array_to_string(rec.roles, ',');
    END LOOP;
    
    -- 7. インデックス確認
    RAISE NOTICE '';
    RAISE NOTICE '=== インデックス一覧 ===';
    FOR rec IN 
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes 
        WHERE schemaname = 'public'
        ORDER BY tablename, indexname
    LOOP
        RAISE NOTICE '✓ %.%: %', rec.schemaname, rec.tablename, rec.indexname;
    END LOOP;
    
    -- 8. 統計情報
    RAISE NOTICE '';
    RAISE NOTICE '=== システム統計 ===';
    
    -- ユーザー統計
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        DECLARE
            total_users INTEGER;
            total_investment DECIMAL;
            nft_holders INTEGER;
            referral_users INTEGER;
        BEGIN
            SELECT COUNT(*) INTO total_users FROM users;
            SELECT COALESCE(SUM(total_purchases), 0) INTO total_investment FROM users;
            SELECT COUNT(*) INTO nft_holders FROM users WHERE total_purchases >= 1000;
            SELECT COUNT(*) INTO referral_users FROM users WHERE referrer_user_id IS NOT NULL;
            
            RAISE NOTICE '総ユーザー数: %', total_users;
            RAISE NOTICE '総投資額: $%', total_investment;
            RAISE NOTICE 'NFT保有者数: %', nft_holders;
            RAISE NOTICE '紹介経由ユーザー数: %', referral_users;
        END;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== 監査完了 ===';
    
END $$;
