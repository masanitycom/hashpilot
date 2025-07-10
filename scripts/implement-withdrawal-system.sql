-- 出金システムの実装

-- 1. 出金申請テーブルの作成
CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    wallet_address TEXT NOT NULL,
    wallet_type VARCHAR(20) NOT NULL DEFAULT 'USDT-TRC20',
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
    admin_notes TEXT,
    transaction_hash TEXT,
    available_usdt_before NUMERIC(15,2) NOT NULL,
    available_usdt_after NUMERIC(15,2) NOT NULL,
    admin_approved_by TEXT,
    admin_approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_withdrawal_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 2. 出金申請関数
CREATE OR REPLACE FUNCTION create_withdrawal_request(
    p_user_id TEXT,
    p_amount NUMERIC,
    p_wallet_address TEXT,
    p_wallet_type TEXT DEFAULT 'USDT-TRC20'
)
RETURNS TABLE(
    request_id UUID,
    status TEXT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_available_usdt NUMERIC;
    v_request_id UUID;
    v_user_exists BOOLEAN;
BEGIN
    -- ユーザー存在確認
    SELECT EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ERROR'::TEXT,
            'ユーザーが存在しません'::TEXT;
        RETURN;
    END IF;
    
    -- 入力値検証
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ERROR'::TEXT,
            '出金額は0より大きい必要があります'::TEXT;
        RETURN;
    END IF;
    
    IF p_amount < 100 THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ERROR'::TEXT,
            '最小出金額は$100です'::TEXT;
        RETURN;
    END IF;
    
    IF LENGTH(p_wallet_address) < 10 THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ERROR'::TEXT,
            '有効なウォレットアドレスを入力してください'::TEXT;
        RETURN;
    END IF;
    
    -- 利用可能残高確認
    SELECT COALESCE(available_usdt, 0) 
    FROM affiliate_cycle 
    WHERE user_id = p_user_id 
    INTO v_available_usdt;
    
    IF v_available_usdt IS NULL THEN
        v_available_usdt := 0;
    END IF;
    
    IF v_available_usdt < p_amount THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ERROR'::TEXT,
            FORMAT('残高不足です。利用可能額: $%s', v_available_usdt)::TEXT;
        RETURN;
    END IF;
    
    -- 保留中の出金申請確認
    IF EXISTS(SELECT 1 FROM withdrawal_requests 
              WHERE user_id = p_user_id AND status = 'pending') THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ERROR'::TEXT,
            '保留中の出金申請があります。完了後に再申請してください'::TEXT;
        RETURN;
    END IF;
    
    -- 出金申請作成
    INSERT INTO withdrawal_requests (
        user_id, amount, wallet_address, wallet_type, 
        available_usdt_before, available_usdt_after,
        status, created_at, updated_at
    )
    VALUES (
        p_user_id, p_amount, p_wallet_address, p_wallet_type,
        v_available_usdt, v_available_usdt - p_amount,
        'pending', NOW(), NOW()
    )
    RETURNING id INTO v_request_id;
    
    -- affiliate_cycleの利用可能残高を減額（仮減額）
    UPDATE affiliate_cycle 
    SET 
        available_usdt = available_usdt - p_amount,
        last_updated = NOW()
    WHERE user_id = p_user_id;
    
    -- ログ記録
    PERFORM log_system_event(
        'INFO',
        'WITHDRAWAL_REQUEST',
        p_user_id,
        FORMAT('出金申請作成: $%s → %s', p_amount, p_wallet_address),
        jsonb_build_object(
            'request_id', v_request_id,
            'amount', p_amount,
            'wallet_address', p_wallet_address,
            'wallet_type', p_wallet_type,
            'available_before', v_available_usdt,
            'available_after', v_available_usdt - p_amount
        )
    );
    
    RETURN QUERY SELECT 
        v_request_id,
        'SUCCESS'::TEXT,
        FORMAT('出金申請を受付ました。申請ID: %s', v_request_id)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        NULL::UUID,
        'ERROR'::TEXT,
        FORMAT('出金申請エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 3. 管理者用出金承認/拒否関数
CREATE OR REPLACE FUNCTION process_withdrawal_request(
    p_request_id UUID,
    p_action TEXT, -- 'approve' または 'reject'
    p_admin_user_id TEXT,
    p_admin_notes TEXT DEFAULT NULL,
    p_transaction_hash TEXT DEFAULT NULL
)
RETURNS TABLE(
    status TEXT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request RECORD;
    v_user_available NUMERIC;
BEGIN
    -- 申請情報取得
    SELECT * FROM withdrawal_requests 
    WHERE id = p_request_id 
    INTO v_request;
    
    IF v_request IS NULL THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            '出金申請が見つかりません'::TEXT;
        RETURN;
    END IF;
    
    IF v_request.status != 'pending' THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            FORMAT('この申請は既に処理済みです（現在のステータス: %s）', v_request.status)::TEXT;
        RETURN;
    END IF;
    
    IF p_action = 'approve' THEN
        -- 承認処理
        UPDATE withdrawal_requests 
        SET 
            status = 'approved',
            admin_approved_by = p_admin_user_id,
            admin_approved_at = NOW(),
            admin_notes = COALESCE(p_admin_notes, '管理者により承認'),
            transaction_hash = p_transaction_hash,
            updated_at = NOW()
        WHERE id = p_request_id;
        
        -- ログ記録
        PERFORM log_system_event(
            'SUCCESS',
            'WITHDRAWAL_APPROVED',
            v_request.user_id,
            FORMAT('出金承認: $%s', v_request.amount),
            jsonb_build_object(
                'request_id', p_request_id,
                'amount', v_request.amount,
                'admin_user', p_admin_user_id,
                'transaction_hash', p_transaction_hash
            )
        );
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT,
            FORMAT('出金申請を承認しました。金額: $%s', v_request.amount)::TEXT;
            
    ELSIF p_action = 'reject' THEN
        -- 拒否処理 - 残高を戻す
        UPDATE affiliate_cycle 
        SET 
            available_usdt = available_usdt + v_request.amount,
            last_updated = NOW()
        WHERE user_id = v_request.user_id;
        
        UPDATE withdrawal_requests 
        SET 
            status = 'rejected',
            admin_approved_by = p_admin_user_id,
            admin_approved_at = NOW(),
            admin_notes = COALESCE(p_admin_notes, '管理者により拒否'),
            updated_at = NOW()
        WHERE id = p_request_id;
        
        -- ログ記録
        PERFORM log_system_event(
            'WARNING',
            'WITHDRAWAL_REJECTED',
            v_request.user_id,
            FORMAT('出金拒否: $%s - %s', v_request.amount, COALESCE(p_admin_notes, '理由未記載')),
            jsonb_build_object(
                'request_id', p_request_id,
                'amount', v_request.amount,
                'admin_user', p_admin_user_id,
                'reason', p_admin_notes
            )
        );
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT,
            FORMAT('出金申請を拒否し、残高を復元しました。金額: $%s', v_request.amount)::TEXT;
            
    ELSE
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            'アクションは "approve" または "reject" である必要があります'::TEXT;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        'ERROR'::TEXT,
        FORMAT('出金処理エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 4. ユーザー出金履歴取得関数
CREATE OR REPLACE FUNCTION get_user_withdrawal_history(
    p_user_id TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    request_id UUID,
    amount NUMERIC,
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    admin_notes TEXT,
    transaction_hash TEXT,
    created_at TIMESTAMP,
    admin_approved_at TIMESTAMP
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wr.id,
        wr.amount,
        wr.wallet_address,
        wr.wallet_type,
        wr.status,
        wr.admin_notes,
        wr.transaction_hash,
        wr.created_at,
        wr.admin_approved_at
    FROM withdrawal_requests wr
    WHERE wr.user_id = p_user_id
    ORDER BY wr.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 5. 管理者用出金申請一覧取得関数
CREATE OR REPLACE FUNCTION get_withdrawal_requests_admin(
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    request_id UUID,
    user_id TEXT,
    amount NUMERIC,
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    admin_notes TEXT,
    transaction_hash TEXT,
    available_usdt_before NUMERIC,
    available_usdt_after NUMERIC,
    created_at TIMESTAMP,
    admin_approved_at TIMESTAMP,
    admin_approved_by TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wr.id,
        wr.user_id,
        wr.amount,
        wr.wallet_address,
        wr.wallet_type,
        wr.status,
        wr.admin_notes,
        wr.transaction_hash,
        wr.available_usdt_before,
        wr.available_usdt_after,
        wr.created_at,
        wr.admin_approved_at,
        wr.admin_approved_by
    FROM withdrawal_requests wr
    WHERE (p_status IS NULL OR wr.status = p_status)
    ORDER BY 
        CASE WHEN wr.status = 'pending' THEN 0 ELSE 1 END,
        wr.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 6. 実行権限付与
GRANT EXECUTE ON FUNCTION create_withdrawal_request(TEXT, NUMERIC, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_withdrawal_request(TEXT, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION process_withdrawal_request(UUID, TEXT, TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION process_withdrawal_request(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_withdrawal_history(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_user_withdrawal_history(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_withdrawal_requests_admin(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_withdrawal_requests_admin(TEXT, INTEGER) TO authenticated;

-- 7. インデックス作成
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user_status ON withdrawal_requests(user_id, status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status_created ON withdrawal_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_admin_created ON withdrawal_requests(admin_approved_by, created_at DESC);

SELECT 'Withdrawal system implemented successfully' as status;