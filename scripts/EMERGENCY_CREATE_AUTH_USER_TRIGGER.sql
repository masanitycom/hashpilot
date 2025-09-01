-- ======================================================
-- HASHPILOT緊急データベーストリガー実装
-- auth.usersテーブル → public.usersテーブル自動同期システム
-- 
-- 問題: 新規登録時にpublic.usersテーブルへの自動同期が欠如
-- 解決: 完全なトリガーシステムによる自動同期とaffiliate_cycle初期化
-- 
-- 実行日: 2025-01-24
-- ======================================================

-- ステップ1: 既存の重複するトリガーを削除（安全措置）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user_trigger ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.sync_auth_user_to_public();

-- ステップ2: 包括的なユーザー同期関数の作成
CREATE OR REPLACE FUNCTION public.handle_new_user_registration()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    referrer_id TEXT;
    coinw_user_id TEXT;
    extracted_referrer TEXT;
    user_meta JSONB;
    operation_start_date DATE;
    rec RECORD;
BEGIN
    -- デバッグログ開始
    RAISE LOG 'AUTH TRIGGER: New user registration started for user %', NEW.id;
    
    -- メタデータの取得と解析
    user_meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
    
    -- 紹介者IDの抽出（複数のキーパターンをサポート）
    referrer_id := COALESCE(
        user_meta->>'referrer_user_id',
        user_meta->>'referrer',
        user_meta->>'ref',
        user_meta->>'referrer_code',
        user_meta->>'referrer_id'
    );
    
    -- CoinW UIDの抽出（複数のキーパターンをサポート）
    coinw_user_id := COALESCE(
        user_meta->>'coinw_uid',
        user_meta->>'coinw',
        user_meta->>'uid',
        user_meta->>'coinw_id'
    );
    
    RAISE LOG 'AUTH TRIGGER: Extracted metadata - referrer: %, coinw_uid: %', referrer_id, coinw_user_id;
    
    -- 紹介者の検証（存在確認）
    IF referrer_id IS NOT NULL AND referrer_id != '' THEN
        SELECT user_id INTO extracted_referrer
        FROM users 
        WHERE user_id = referrer_id
        LIMIT 1;
        
        IF extracted_referrer IS NULL THEN
            RAISE LOG 'AUTH TRIGGER: Referrer % not found in users table, setting to NULL', referrer_id;
            referrer_id := NULL;
        ELSE
            RAISE LOG 'AUTH TRIGGER: Referrer % validated successfully', referrer_id;
        END IF;
    END IF;
    
    -- 運用開始日の計算（承認日から15日後）
    operation_start_date := CURRENT_DATE + INTERVAL '15 days';
    
    -- public.usersテーブルへのINSERT（重複回避）
    BEGIN
        INSERT INTO public.users (
            id,
            user_id,
            email,
            full_name,
            referrer_user_id,
            coinw_uid,
            nft_receive_address,
            created_at,
            updated_at,
            is_active,
            total_purchases,
            total_referral_earnings,
            has_approved_nft,
            operation_start_date
        ) VALUES (
            NEW.id,
            NEW.id,  -- auth.usersのidをuser_idとして使用
            COALESCE(NEW.email, ''),
            COALESCE(user_meta->>'full_name', NULL),
            referrer_id,
            coinw_user_id,
            NULL,  -- 初期値はNULL
            COALESCE(NEW.created_at, NOW()),
            NOW(),
            true,  -- デフォルトでアクティブ
            0,     -- 初期購入額は0
            0,     -- 初期紹介報酬は0
            false, -- NFT未承認
            operation_start_date  -- 15日後の運用開始日
        );
        
        RAISE LOG 'AUTH TRIGGER: Successfully inserted user % into public.users', NEW.id;
        
    EXCEPTION 
        WHEN unique_violation THEN
            RAISE LOG 'AUTH TRIGGER: User % already exists in public.users, skipping insert', NEW.id;
        WHEN OTHERS THEN
            RAISE LOG 'AUTH TRIGGER: Error inserting user % into public.users: %', NEW.id, SQLERRM;
            -- エラーでもトリガーは成功させる（認証プロセスを阻害しない）
    END;
    
    -- affiliate_cycleテーブルへの初期レコード作成
    BEGIN
        INSERT INTO public.affiliate_cycle (
            user_id,
            cycle_start_date,
            cycle_end_date,
            phase,
            total_nft_count,
            manual_nft_count,
            auto_purchased_nft_count,
            previous_cycle_nft_count,
            cum_usdt,
            available_usdt,
            next_action,
            cycle_number,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,  -- user_idとして使用
            CURRENT_DATE,
            CURRENT_DATE + INTERVAL '30 days',  -- 初期サイクル30日
            'waiting_purchase',  -- 購入待ち状態
            0,   -- 初期NFT数
            0,   -- 手動購入NFT数
            0,   -- 自動購入NFT数
            0,   -- 前回サイクルからのNFT数
            0,   -- 累積USDT
            0,   -- 利用可能USDT
            'user_needs_to_purchase_nft',  -- ユーザーはNFT購入が必要
            1,   -- 初回サイクル
            NOW(),
            NOW()
        );
        
        RAISE LOG 'AUTH TRIGGER: Successfully created affiliate_cycle record for user %', NEW.id;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE LOG 'AUTH TRIGGER: affiliate_cycle record already exists for user %, skipping', NEW.id;
        WHEN OTHERS THEN
            RAISE LOG 'AUTH TRIGGER: Error creating affiliate_cycle for user %: %', NEW.id, SQLERRM;
            -- エラーでもトリガーは成功させる
    END;
    
    RAISE LOG 'AUTH TRIGGER: User registration process completed successfully for user %', NEW.id;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- 全体的なエラーハンドリング
        RAISE LOG 'AUTH TRIGGER: Critical error in user registration for %: %', NEW.id, SQLERRM;
        -- 認証プロセスを停止させないため、エラーでもNEWを返す
        RETURN NEW;
END;
$$;

-- ステップ3: auth.usersテーブルへのトリガー設定
CREATE TRIGGER handle_auth_user_registration
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_registration();

-- ステップ4: 既存ユーザーの同期修正関数（必要に応じて）
CREATE OR REPLACE FUNCTION public.sync_existing_auth_users()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    auth_user RECORD;
    user_meta JSONB;
    referrer_id TEXT;
    coinw_user_id TEXT;
    operation_start_date DATE;
BEGIN
    RAISE LOG 'SYNC: Starting sync of existing auth users to public.users';
    
    -- auth.usersテーブルから、public.usersに存在しないユーザーを取得
    FOR auth_user IN 
        SELECT au.id, au.email, au.created_at, au.raw_user_meta_data
        FROM auth.users au
        LEFT JOIN public.users pu ON au.id = pu.id
        WHERE pu.id IS NULL
    LOOP
        user_meta := COALESCE(auth_user.raw_user_meta_data, '{}'::jsonb);
        
        -- メタデータから紹介者情報を抽出
        referrer_id := COALESCE(
            user_meta->>'referrer_user_id',
            user_meta->>'referrer',
            user_meta->>'ref',
            user_meta->>'referrer_code',
            user_meta->>'referrer_id'
        );
        
        -- CoinW UID抽出
        coinw_user_id := COALESCE(
            user_meta->>'coinw_uid',
            user_meta->>'coinw',
            user_meta->>'uid',
            user_meta->>'coinw_id'
        );
        
        -- 運用開始日計算
        operation_start_date := CURRENT_DATE + INTERVAL '15 days';
        
        -- public.usersへ挿入
        BEGIN
            INSERT INTO public.users (
                id, user_id, email, full_name, referrer_user_id, coinw_uid,
                nft_receive_address, created_at, updated_at, is_active,
                total_purchases, total_referral_earnings, has_approved_nft,
                operation_start_date
            ) VALUES (
                auth_user.id, auth_user.id, COALESCE(auth_user.email, ''),
                user_meta->>'full_name', referrer_id, coinw_user_id,
                NULL, auth_user.created_at, NOW(), true,
                0, 0, false, operation_start_date
            );
            
            RAISE LOG 'SYNC: Added user % to public.users', auth_user.id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE LOG 'SYNC: Error adding user % to public.users: %', auth_user.id, SQLERRM;
        END;
        
        -- affiliate_cycleレコード作成
        BEGIN
            INSERT INTO public.affiliate_cycle (
                user_id, cycle_start_date, cycle_end_date, phase,
                total_nft_count, manual_nft_count, auto_purchased_nft_count,
                previous_cycle_nft_count, cum_usdt, available_usdt,
                next_action, cycle_number, created_at, updated_at
            ) VALUES (
                auth_user.id, CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
                'waiting_purchase', 0, 0, 0, 0, 0, 0,
                'user_needs_to_purchase_nft', 1, NOW(), NOW()
            );
            
            RAISE LOG 'SYNC: Added affiliate_cycle for user %', auth_user.id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE LOG 'SYNC: Error adding affiliate_cycle for user % : %', auth_user.id, SQLERRM;
        END;
        
    END LOOP;
    
    RAISE LOG 'SYNC: Completed sync of existing auth users';
END;
$$;

-- ステップ5: トリガー機能の検証関数
CREATE OR REPLACE FUNCTION public.test_auth_trigger_system()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    details TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    -- トリガーの存在確認
    RETURN QUERY
    SELECT 
        'Trigger Existence Check'::TEXT,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM information_schema.triggers 
                WHERE trigger_name = 'handle_auth_user_registration'
                  AND event_object_table = 'users'
                  AND event_object_schema = 'auth'
            ) 
            THEN 'SUCCESS'::TEXT 
            ELSE 'FAILED'::TEXT 
        END,
        'Auth user registration trigger check'::TEXT;
    
    -- 関数の存在確認
    RETURN QUERY
    SELECT 
        'Function Existence Check'::TEXT,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM information_schema.routines 
                WHERE routine_name = 'handle_new_user_registration'
                  AND routine_schema = 'public'
            ) 
            THEN 'SUCCESS'::TEXT 
            ELSE 'FAILED'::TEXT 
        END,
        'User registration function check'::TEXT;
    
    -- テーブル構造確認
    RETURN QUERY
    SELECT 
        'Table Structure Check'::TEXT,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'users' 
                  AND table_schema = 'public'
                  AND column_name = 'referrer_user_id'
            ) 
            AND EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'users' 
                  AND table_schema = 'public'
                  AND column_name = 'coinw_uid'
            )
            THEN 'SUCCESS'::TEXT 
            ELSE 'FAILED'::TEXT 
        END,
        'Required columns in public.users table'::TEXT;
        
    RETURN;
END;
$$;

-- ステップ6: 実行確認とログ出力
DO $$
BEGIN
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'HASHPILOT 緊急データベーストリガー実装完了';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '✓ auth.users → public.users 自動同期トリガー作成完了';
    RAISE NOTICE '✓ 紹介者情報(raw_user_meta_data)自動抽出機能実装';
    RAISE NOTICE '✓ CoinW UID自動抽出・設定機能実装';
    RAISE NOTICE '✓ affiliate_cycle初期レコード自動作成機能実装';
    RAISE NOTICE '✓ エラーハンドリングと認証プロセス保護実装';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '次の手順:';
    RAISE NOTICE '1. SELECT * FROM public.test_auth_trigger_system(); で検証';
    RAISE NOTICE '2. 必要に応じて SELECT public.sync_existing_auth_users(); で既存ユーザー同期';
    RAISE NOTICE '3. 新規登録テストで動作確認';
    RAISE NOTICE '======================================================';
END;
$$;

-- ステップ7: セキュリティとパフォーマンス設定
-- トリガー関数の実行権限を適切に設定
GRANT EXECUTE ON FUNCTION public.handle_new_user_registration() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_existing_auth_users() TO service_role;
GRANT EXECUTE ON FUNCTION public.test_auth_trigger_system() TO authenticated, service_role;

-- ステップ8: 最終検証クエリの実行
SELECT 
    '🔧 TRIGGER INSTALLATION STATUS' as status,
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name = 'handle_auth_user_registration'
   OR trigger_name LIKE '%auth%user%';

-- 完了通知
SELECT '✅ EMERGENCY AUTH TRIGGER SYSTEM INSTALLED SUCCESSFULLY' as completion_status;