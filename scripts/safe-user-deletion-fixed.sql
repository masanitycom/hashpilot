-- 安全なユーザー削除機能（テーブル名修正版）
-- withdrawal_requestsテーブルの存在確認付き

-- 1. 現在のテーブル構造を確認
SELECT 
    table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name IN ('users', 'purchases', 'affiliate_cycle', 'withdrawal_requests', 'buyback_requests', 'user_daily_profit', 'system_logs')
ORDER BY table_name;

-- 2. 外部キー制約を確認（変更しません）
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND ccu.table_name = 'users';

-- 3. 安全なユーザー削除関数（修正版）
CREATE OR REPLACE FUNCTION public.delete_user_safely(
    p_user_id TEXT,
    p_admin_email TEXT
)
RETURNS TABLE (
    status TEXT,
    message TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_exists BOOLEAN;
    v_user_exists BOOLEAN;
    v_user_email TEXT;
    v_total_purchases NUMERIC := 0;
    v_affiliate_cycle_exists BOOLEAN;
    v_referrals_count INTEGER := 0;
    v_purchases_count INTEGER := 0;
    v_withdrawals_count INTEGER := 0;
    v_buybacks_count INTEGER := 0;
    v_table_exists BOOLEAN;
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
        RETURN QUERY SELECT 'ERROR'::TEXT, '管理者権限がありません'::TEXT;
        RETURN;
    END IF;

    -- ユーザー存在確認と詳細取得
    SELECT 
        EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id),
        email,
        COALESCE(total_purchases, 0)
    INTO v_user_exists, v_user_email, v_total_purchases
    FROM users 
    WHERE user_id = p_user_id;

    IF NOT v_user_exists THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, 'ユーザーが見つかりません'::TEXT;
        RETURN;
    END IF;

    -- 関連データの存在確認（テーブル存在チェック付き）
    SELECT EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = p_user_id) INTO v_affiliate_cycle_exists;
    SELECT COUNT(*) INTO v_referrals_count FROM users WHERE referrer_user_id = p_user_id;
    SELECT COUNT(*) INTO v_purchases_count FROM purchases WHERE user_id = p_user_id;
    
    -- withdrawal_requestsテーブルが存在する場合のみカウント
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'withdrawal_requests'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        SELECT COUNT(*) INTO v_withdrawals_count FROM withdrawal_requests WHERE user_id = p_user_id;
    ELSE
        v_withdrawals_count := 0;
    END IF;
    
    -- buyback_requestsテーブルが存在する場合のみカウント
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'buyback_requests'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        SELECT COUNT(*) INTO v_buybacks_count FROM buyback_requests WHERE user_id = p_user_id;
    ELSE
        v_buybacks_count := 0;
    END IF;

    -- 削除処理（外部キー制約を考慮した安全な順序）
    BEGIN
        -- Step 1: 紹介関係を先に解除
        UPDATE users 
        SET referrer_user_id = NULL 
        WHERE referrer_user_id = p_user_id;
        
        -- Step 2: 子テーブルから順番に削除
        
        -- buyback_requestsが存在する場合のみ削除
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'buyback_requests') THEN
            DELETE FROM buyback_requests WHERE user_id = p_user_id;
        END IF;
        
        -- withdrawal_requestsが存在する場合のみ削除
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'withdrawal_requests') THEN
            DELETE FROM withdrawal_requests WHERE user_id = p_user_id;
        END IF;
        
        -- user_daily_profitが存在する場合のみ削除
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_daily_profit') THEN
            DELETE FROM user_daily_profit WHERE user_id = p_user_id;
        END IF;
        
        -- daily_profit_recordsが存在する場合のみ削除（別名の可能性）
        IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'daily_profit_records') THEN
            DELETE FROM daily_profit_records WHERE user_id = p_user_id;
        END IF;
        
        -- NFT購入記録を削除
        DELETE FROM purchases WHERE user_id = p_user_id;
        
        -- システムログを削除（ユーザー関連のみ）
        DELETE FROM system_logs WHERE user_id = p_user_id AND log_type != 'ADMIN';
        
        -- Step 3: affiliate_cycle を削除（最重要）
        DELETE FROM affiliate_cycle WHERE user_id = p_user_id;
        
        -- Step 4: 最後にユーザー本体を削除
        DELETE FROM users WHERE user_id = p_user_id;
        
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
            FORMAT('ユーザーアカウント %s (%s) が安全に削除されました', p_user_id, v_user_email),
            jsonb_build_object(
                'deleted_by', p_admin_email,
                'deleted_user_email', v_user_email,
                'had_purchases', v_purchases_count > 0,
                'had_affiliate_cycle', v_affiliate_cycle_exists,
                'had_withdrawals', v_withdrawals_count > 0,
                'had_buybacks', v_buybacks_count > 0,
                'referred_users_count', v_referrals_count,
                'total_purchases_amount', v_total_purchases,
                'deletion_method', 'safe_manual_cascade_with_checks'
            ),
            NOW()
        );
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            FORMAT('ユーザー %s (%s) を安全に削除しました。関連データ: 購入%s件、出金%s件、買取%s件、紹介%s名', 
                   p_user_id, v_user_email, v_purchases_count, v_withdrawals_count, v_buybacks_count, v_referrals_count)::TEXT;
        
    EXCEPTION WHEN OTHERS THEN
        -- 詳細なエラー情報を返す
        RETURN QUERY SELECT 'ERROR'::TEXT, FORMAT('削除エラー: %s (SQLState: %s)', SQLERRM, SQLSTATE)::TEXT;
    END;
END;
$$;

-- 4. 権限設定
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO service_role;

-- 5. テスト用：削除候補となるユーザーを安全に確認（修正版）
WITH table_checks AS (
    SELECT 
        EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'withdrawal_requests') as has_withdrawals_table,
        EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'buyback_requests') as has_buybacks_table
)
SELECT 
    u.user_id,
    u.email,
    u.full_name,
    u.created_at,
    COALESCE(u.total_purchases, 0) as total_purchases,
    u.has_approved_nft,
    EXISTS(SELECT 1 FROM affiliate_cycle ac WHERE ac.user_id = u.user_id) as has_affiliate_cycle,
    (SELECT COUNT(*) FROM purchases p WHERE p.user_id = u.user_id) as purchases_count,
    CASE WHEN tc.has_withdrawals_table THEN 
        (SELECT COUNT(*) FROM withdrawal_requests WHERE user_id = u.user_id) 
    ELSE 0 END as withdrawals_count,
    CASE WHEN tc.has_buybacks_table THEN 
        (SELECT COUNT(*) FROM buyback_requests WHERE user_id = u.user_id) 
    ELSE 0 END as buybacks_count,
    (SELECT COUNT(*) FROM users ref WHERE ref.referrer_user_id = u.user_id) as referrals_count
FROM users u, table_checks tc
WHERE 
    (u.email LIKE '%test%' OR u.email LIKE '%demo%' OR u.email LIKE '%temp%')
    OR (u.created_at > NOW() - INTERVAL '7 days' AND COALESCE(u.total_purchases, 0) = 0)
ORDER BY u.created_at DESC
LIMIT 10;

-- 6. 動作確認メッセージ
SELECT 'Safe user deletion function created with table existence checks' as result;