-- 安全なユーザー削除機能（外部キー制約は変更せず、関数のみで対応）
-- 既存のデータベース構造には一切変更を加えません

-- 1. 現在の制約状況を確認（変更しません）
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name = 'affiliate_cycle'
AND ccu.table_name = 'users';

-- 2. 安全なユーザー削除関数（制約は変更せず手動で順序制御）
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

    -- 関連データの存在確認
    SELECT EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = p_user_id) INTO v_affiliate_cycle_exists;
    SELECT COUNT(*) INTO v_referrals_count FROM users WHERE referrer_user_id = p_user_id;
    SELECT COUNT(*) INTO v_purchases_count FROM purchases WHERE user_id = p_user_id;
    SELECT COUNT(*) INTO v_withdrawals_count FROM withdrawal_requests WHERE user_id = p_user_id;
    SELECT COUNT(*) INTO v_buybacks_count FROM buyback_requests WHERE user_id = p_user_id;

    -- 削除処理（外部キー制約を考慮した安全な順序）
    BEGIN
        -- Step 1: 紹介関係を先に解除（他ユーザーの参照を無効化）
        UPDATE users 
        SET referrer_user_id = NULL 
        WHERE referrer_user_id = p_user_id;
        
        -- Step 2: 子テーブルから順番に削除（外部キー制約順序）
        
        -- 買い取り申請を削除
        DELETE FROM buyback_requests WHERE user_id = p_user_id;
        
        -- 出金申請を削除
        DELETE FROM withdrawal_requests WHERE user_id = p_user_id;
        
        -- 日利記録を削除
        DELETE FROM user_daily_profit WHERE user_id = p_user_id;
        
        -- NFT購入記録を削除
        DELETE FROM purchases WHERE user_id = p_user_id;
        
        -- システムログを削除（ユーザー関連のみ、管理者操作ログは保持）
        DELETE FROM system_logs WHERE user_id = p_user_id AND log_type != 'ADMIN';
        
        -- Step 3: affiliate_cycle を削除（最重要：外部キー制約の主因）
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
                'deletion_method', 'safe_manual_cascade'
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

-- 3. 権限設定
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.delete_user_safely(TEXT, TEXT) TO service_role;

-- 4. テスト用：削除候補となるユーザーを安全に確認（テーブル存在チェック付き）
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
    -- 安全に削除できそうなユーザーの条件
    (u.email LIKE '%test%' OR u.email LIKE '%demo%' OR u.email LIKE '%temp%')
    OR (u.created_at > NOW() - INTERVAL '7 days' AND COALESCE(u.total_purchases, 0) = 0)
ORDER BY u.created_at DESC
LIMIT 10;

-- 5. 動作確認メッセージ
SELECT 'Safe user deletion function created - no database constraints modified' as result;

-- 使用方法の説明
SELECT '使用方法: SELECT * FROM delete_user_safely(''ユーザーID'', ''管理者メール'');' as usage_info;