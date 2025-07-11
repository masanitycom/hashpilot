-- 管理者が買い取り申請を処理する関数

CREATE OR REPLACE FUNCTION process_buyback_request(
    p_request_id UUID,
    p_action TEXT,
    p_admin_user_id UUID,
    p_transaction_hash TEXT DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request RECORD;
    v_admin_email TEXT;
    v_new_status TEXT;
BEGIN
    -- 管理者確認
    SELECT email INTO v_admin_email
    FROM auth.users
    WHERE id = p_admin_user_id;
    
    IF NOT EXISTS (
        SELECT 1 FROM admins 
        WHERE email = v_admin_email 
        AND is_active = true
    ) THEN
        RETURN QUERY
        SELECT 
            FALSE,
            '管理者権限がありません'::TEXT;
        RETURN;
    END IF;
    
    -- 申請情報を取得
    SELECT * INTO v_request
    FROM buyback_requests
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            FALSE,
            '申請が見つかりません'::TEXT;
        RETURN;
    END IF;
    
    -- 既に処理済みかチェック
    IF v_request.status != 'pending' THEN
        RETURN QUERY
        SELECT 
            FALSE,
            '申請は既に処理済みです'::TEXT;
        RETURN;
    END IF;
    
    -- アクションに基づいてステータスを設定
    IF p_action = 'complete' THEN
        v_new_status := 'completed';
        
        -- トランザクションハッシュが必須
        IF p_transaction_hash IS NULL OR p_transaction_hash = '' THEN
            RETURN QUERY
            SELECT 
                FALSE,
                'トランザクションハッシュが必要です'::TEXT;
            RETURN;
        END IF;
    ELSIF p_action = 'cancel' THEN
        v_new_status := 'cancelled';
        
        -- キャンセルの場合はNFTを戻す
        UPDATE affiliate_cycle
        SET 
            manual_nft_count = manual_nft_count + v_request.manual_nft_count,
            auto_nft_count = auto_nft_count + v_request.auto_nft_count,
            total_nft_count = total_nft_count + v_request.total_nft_count,
            last_updated = NOW()
        WHERE user_id = v_request.user_id;
    ELSE
        RETURN QUERY
        SELECT 
            FALSE,
            '無効なアクションです'::TEXT;
        RETURN;
    END IF;
    
    -- 申請を更新
    UPDATE buyback_requests
    SET 
        status = v_new_status,
        processed_by = v_admin_email,
        processed_at = NOW(),
        transaction_hash = p_transaction_hash,
        admin_notes = p_admin_notes,
        updated_at = NOW()
    WHERE id = p_request_id;
    
    -- ログ記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    )
    VALUES (
        'buyback_request',
        p_action,
        v_request.user_id,
        'NFT買い取り申請処理: ' || v_new_status,
        jsonb_build_object(
            'request_id', p_request_id,
            'admin', v_admin_email,
            'action', p_action,
            'transaction_hash', p_transaction_hash
        ),
        NOW()
    );
    
    RETURN QUERY
    SELECT 
        TRUE,
        ('買い取り申請を' || 
         CASE v_new_status 
            WHEN 'completed' THEN '完了' 
            WHEN 'cancelled' THEN 'キャンセル' 
         END || 
         'しました')::TEXT;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, UUID, TEXT, TEXT) TO authenticated;