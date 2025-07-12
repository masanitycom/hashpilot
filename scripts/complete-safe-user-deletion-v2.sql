-- 完全版：安全なユーザー削除関数（既存関数削除付き）

-- 1. 既存の関数を削除
DROP FUNCTION IF EXISTS public.delete_user_safely(TEXT, TEXT);

-- 2. 新しい関数を作成（返り値にdetails追加）
CREATE OR REPLACE FUNCTION public.delete_user_safely(
    p_user_id TEXT,
    p_admin_email TEXT
)
RETURNS TABLE (
    status TEXT,
    message TEXT,
    details JSONB
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_exists BOOLEAN;
    v_user_exists BOOLEAN;
    v_user_email TEXT;
    v_total_purchases NUMERIC := 0;
    v_referrals_count INTEGER := 0;
    v_deleted_tables JSONB := '[]'::JSONB;
    v_table_name TEXT;
    v_row_count INTEGER;
BEGIN
    -- 管理者権限確認
    SELECT EXISTS(
        SELECT 1 FROM admins 
        WHERE email = p_admin_email AND is_active = true
    ) INTO v_admin_exists;

    -- 緊急アクセス権限
    IF NOT v_admin_exists AND p_admin_email IN ('basarasystems@gmail.com', 'support@dshsupport.biz', 'masataka.tak@gmail.com') THEN
        v_admin_exists := true;
    END IF;

    IF NOT v_admin_exists THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            '管理者権限がありません'::TEXT,
            NULL::JSONB;
        RETURN;
    END IF;

    -- ユーザー存在確認
    SELECT 
        EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id),
        email,
        COALESCE(total_purchases, 0)
    INTO v_user_exists, v_user_email, v_total_purchases
    FROM users 
    WHERE user_id = p_user_id;

    IF NOT v_user_exists THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'ユーザーが見つかりません'::TEXT,
            NULL::JSONB;
        RETURN;
    END IF;

    -- 紹介したユーザー数をカウント
    SELECT COUNT(*) INTO v_referrals_count 
    FROM users WHERE referrer_user_id = p_user_id;

    -- 削除処理開始
    BEGIN
        -- Step 1: 自己参照の解除（users テーブルの referrer_user_id）
        UPDATE users 
        SET referrer_user_id = NULL 
        WHERE referrer_user_id = p_user_id;
        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        IF v_row_count > 0 THEN
            v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'users.referrer_user_id', 'rows', v_row_count);
        END IF;

        -- Step 2: 各テーブルから安全に削除（存在チェック付き）
        
        -- referrals テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'referrals') THEN
            DELETE FROM referrals WHERE referrer_user_id = p_user_id OR referred_user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'referrals', 'rows', v_row_count);
            END IF;
        END IF;

        -- referral_commissions テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'referral_commissions') THEN
            DELETE FROM referral_commissions WHERE referrer_user_id = p_user_id OR referred_user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'referral_commissions', 'rows', v_row_count);
            END IF;
        END IF;

        -- affiliate_reward テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'affiliate_reward') THEN
            DELETE FROM affiliate_reward WHERE user_id = p_user_id OR referral_user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'affiliate_reward', 'rows', v_row_count);
            END IF;
        END IF;

        -- user_monthly_rewards テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_monthly_rewards') THEN
            DELETE FROM user_monthly_rewards WHERE user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'user_monthly_rewards', 'rows', v_row_count);
            END IF;
        END IF;

        -- user_withdrawal_settings テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_withdrawal_settings') THEN
            DELETE FROM user_withdrawal_settings WHERE user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'user_withdrawal_settings', 'rows', v_row_count);
            END IF;
        END IF;

        -- nft_holdings テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'nft_holdings') THEN
            DELETE FROM nft_holdings WHERE user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'nft_holdings', 'rows', v_row_count);
            END IF;
        END IF;

        -- user_daily_profit テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_daily_profit') THEN
            DELETE FROM user_daily_profit WHERE user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'user_daily_profit', 'rows', v_row_count);
            END IF;
        END IF;

        -- buyback_requests テーブル
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'buyback_requests') THEN
            DELETE FROM buyback_requests WHERE user_id = p_user_id;
            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            IF v_row_count > 0 THEN
                v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'buyback_requests', 'rows', v_row_count);
            END IF;
        END IF;

        -- purchases テーブル
        DELETE FROM purchases WHERE user_id = p_user_id;
        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        IF v_row_count > 0 THEN
            v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'purchases', 'rows', v_row_count);
        END IF;

        -- affiliate_cycle テーブル（重要）
        DELETE FROM affiliate_cycle WHERE user_id = p_user_id;
        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        IF v_row_count > 0 THEN
            v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'affiliate_cycle', 'rows', v_row_count);
        END IF;

        -- system_logs テーブル（ユーザー関連のみ）
        DELETE FROM system_logs WHERE user_id = p_user_id AND log_type != 'ADMIN';
        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        IF v_row_count > 0 THEN
            v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'system_logs', 'rows', v_row_count);
        END IF;

        -- Step 3: 最後にユーザー本体を削除
        DELETE FROM users WHERE user_id = p_user_id;
        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'users', 'rows', v_row_count);

        -- 削除完了ログを記録
        INSERT INTO system_logs (
            log_type,
            operation,
            user_id,
            message,
            details,
            created_at
        ) VALUES (
            'ADMIN',
            'user_deleted_safely',
            p_user_id,
            FORMAT('ユーザー %s (%s) が完全に削除されました', p_user_id, v_user_email),
            jsonb_build_object(
                'deleted_by', p_admin_email,
                'deleted_user_email', v_user_email,
                'total_purchases_amount', v_total_purchases,
                'referred_users_count', v_referrals_count,
                'deleted_from_tables', v_deleted_tables
            ),
            NOW()
        );
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            FORMAT('ユーザー %s (%s) を完全に削除しました', p_user_id, v_user_email)::TEXT,
            jsonb_build_object(
                'user_id', p_user_id,
                'email', v_user_email,
                'total_purchases', v_total_purchases,
                'referred_users', v_referrals_count,
                'deleted_from_tables', v_deleted_tables
            );
        
    EXCEPTION WHEN OTHERS THEN
        -- 詳細なエラー情報を返す
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            FORMAT('削除エラー: %s', SQLERRM)::TEXT,
            jsonb_build_object(
                'error_detail', SQLERRM,
                'error_state', SQLSTATE,
                'partially_deleted_tables', v_deleted_tables
            );
    END;
END;
$$;

-- 3. 権限設定
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO service_role;

-- 4. 削除可能なユーザーを確認
SELECT 
    u.user_id,
    u.email,
    u.full_name,
    u.created_at::date as created_date,
    COALESCE(u.total_purchases, 0) as total_purchases,
    u.has_approved_nft,
    EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = u.user_id) as has_affiliate_cycle,
    (SELECT COUNT(*) FROM purchases WHERE user_id = u.user_id) as purchases_count,
    (SELECT COUNT(*) FROM buyback_requests WHERE user_id = u.user_id) as buybacks_count,
    (SELECT COUNT(*) FROM users WHERE referrer_user_id = u.user_id) as referrals_count
FROM users u
WHERE 
    -- 削除候補の条件（テストユーザーや最近の未購入ユーザー）
    (u.email LIKE '%test%' OR u.email LIKE '%demo%')
    OR (u.created_at > NOW() - INTERVAL '7 days' AND COALESCE(u.total_purchases, 0) = 0)
ORDER BY u.created_at DESC
LIMIT 10;

-- 5. 関数の動作テスト（DRY RUN）
-- 実際には削除せず、削除されるデータを確認
WITH target_user AS (
    SELECT user_id, email
    FROM users
    WHERE email LIKE '%test%'
    LIMIT 1
)
SELECT 
    'DRY RUN - 以下のデータが削除されます:' as info,
    tu.user_id,
    tu.email,
    jsonb_build_object(
        'users.referrer_user_id', (SELECT COUNT(*) FROM users WHERE referrer_user_id = tu.user_id),
        'referrals', (SELECT COUNT(*) FROM referrals WHERE referrer_user_id = tu.user_id OR referred_user_id = tu.user_id),
        'referral_commissions', (SELECT COUNT(*) FROM referral_commissions WHERE referrer_user_id = tu.user_id OR referred_user_id = tu.user_id),
        'purchases', (SELECT COUNT(*) FROM purchases WHERE user_id = tu.user_id),
        'affiliate_cycle', (SELECT COUNT(*) FROM affiliate_cycle WHERE user_id = tu.user_id),
        'affiliate_reward', (SELECT COUNT(*) FROM affiliate_reward WHERE user_id = tu.user_id OR referral_user_id = tu.user_id),
        'nft_holdings', (SELECT COUNT(*) FROM nft_holdings WHERE user_id = tu.user_id),
        'user_daily_profit', (SELECT COUNT(*) FROM user_daily_profit WHERE user_id = tu.user_id),
        'user_monthly_rewards', (SELECT COUNT(*) FROM user_monthly_rewards WHERE user_id = tu.user_id),
        'user_withdrawal_settings', (SELECT COUNT(*) FROM user_withdrawal_settings WHERE user_id = tu.user_id),
        'buyback_requests', (SELECT COUNT(*) FROM buyback_requests WHERE user_id = tu.user_id),
        'system_logs', (SELECT COUNT(*) FROM system_logs WHERE user_id = tu.user_id AND log_type != 'ADMIN')
    ) as affected_records
FROM target_user tu;

-- 6. 動作確認
SELECT 'Complete user deletion function v2 created successfully' as result;