-- NFT買い取りシステムの実装

-- 1. buyback_requestsテーブルを作成
CREATE TABLE IF NOT EXISTS buyback_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(user_id),
    request_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- NFT詳細
    manual_nft_count INTEGER NOT NULL DEFAULT 0,
    auto_nft_count INTEGER NOT NULL DEFAULT 0,
    total_nft_count INTEGER NOT NULL,
    
    -- 買い取り金額
    manual_buyback_amount NUMERIC(10,2) NOT NULL DEFAULT 0, -- 手動NFT買い取り額
    auto_buyback_amount NUMERIC(10,2) NOT NULL DEFAULT 0,   -- 自動NFT買い取り額  
    total_buyback_amount NUMERIC(10,2) NOT NULL,            -- 合計買い取り額
    
    -- 送金情報
    wallet_address TEXT NOT NULL,
    wallet_type TEXT DEFAULT 'USDT-BEP20',
    
    -- ステータス
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'cancelled')),
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    admin_notes TEXT,
    
    -- メタデータ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. インデックス作成
CREATE INDEX idx_buyback_requests_user_id ON buyback_requests(user_id);
CREATE INDEX idx_buyback_requests_status ON buyback_requests(status);
CREATE INDEX idx_buyback_requests_created_at ON buyback_requests(created_at DESC);

-- 3. affiliate_cycleテーブルにbuyback関連カラムを追加
ALTER TABLE affiliate_cycle ADD COLUMN IF NOT EXISTS pending_buyback_manual INTEGER DEFAULT 0;
ALTER TABLE affiliate_cycle ADD COLUMN IF NOT EXISTS pending_buyback_auto INTEGER DEFAULT 0;

-- 4. 買い取り申請作成関数
CREATE OR REPLACE FUNCTION create_buyback_request(
    p_user_id TEXT,
    p_manual_nft_count INTEGER,
    p_auto_nft_count INTEGER,
    p_wallet_address TEXT,
    p_wallet_type TEXT DEFAULT 'USDT-BEP20'
)
RETURNS TABLE(
    success BOOLEAN,
    request_id UUID,
    message TEXT,
    total_amount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id UUID;
    v_user_profit_total NUMERIC;
    v_manual_buyback NUMERIC;
    v_auto_buyback NUMERIC;
    v_total_buyback NUMERIC;
    v_current_manual INTEGER;
    v_current_auto INTEGER;
BEGIN
    -- ユーザーの現在のNFT数を確認
    SELECT manual_nft_count, auto_nft_count
    INTO v_current_manual, v_current_auto
    FROM affiliate_cycle
    WHERE user_id = p_user_id;
    
    -- 十分なNFTがあるか確認
    IF v_current_manual < p_manual_nft_count OR v_current_auto < p_auto_nft_count THEN
        RETURN QUERY SELECT 
            false,
            NULL::UUID,
            'Insufficient NFTs for buyback request',
            0::NUMERIC;
        RETURN;
    END IF;
    
    -- 手動NFTの買い取り額計算（1000 - 累積利益）
    -- TODO: 実際の累積利益を計算する必要がある
    SELECT COALESCE(SUM(daily_profit), 0)
    INTO v_user_profit_total
    FROM user_daily_profit
    WHERE user_id = p_user_id;
    
    -- 買い取り額計算
    v_manual_buyback := GREATEST(0, (1000 * p_manual_nft_count) - (v_user_profit_total / v_current_manual * p_manual_nft_count));
    v_auto_buyback := 500 * p_auto_nft_count; -- 自動NFTは一律500ドル
    v_total_buyback := v_manual_buyback + v_auto_buyback;
    
    -- 買い取り申請を作成
    INSERT INTO buyback_requests (
        user_id,
        manual_nft_count,
        auto_nft_count,
        total_nft_count,
        manual_buyback_amount,
        auto_buyback_amount,
        total_buyback_amount,
        wallet_address,
        wallet_type
    )
    VALUES (
        p_user_id,
        p_manual_nft_count,
        p_auto_nft_count,
        p_manual_nft_count + p_auto_nft_count,
        v_manual_buyback,
        v_auto_buyback,
        v_total_buyback,
        p_wallet_address,
        p_wallet_type
    )
    RETURNING id INTO v_request_id;
    
    -- affiliate_cycleを更新（NFT数を減らし、pending_buybackに追加）
    UPDATE affiliate_cycle
    SET 
        manual_nft_count = manual_nft_count - p_manual_nft_count,
        auto_nft_count = auto_nft_count - p_auto_nft_count,
        total_nft_count = total_nft_count - (p_manual_nft_count + p_auto_nft_count),
        pending_buyback_manual = pending_buyback_manual + p_manual_nft_count,
        pending_buyback_auto = pending_buyback_auto + p_auto_nft_count,
        last_updated = NOW()
    WHERE user_id = p_user_id;
    
    -- システムログに記録
    INSERT INTO system_logs (
        log_type, operation, user_id, message, details
    )
    VALUES (
        'INFO',
        'BUYBACK_REQUEST_CREATED',
        p_user_id,
        format('Buyback request created: %s manual + %s auto NFTs for $%s', 
               p_manual_nft_count, p_auto_nft_count, v_total_buyback),
        jsonb_build_object(
            'request_id', v_request_id,
            'manual_nft', p_manual_nft_count,
            'auto_nft', p_auto_nft_count,
            'total_amount', v_total_buyback
        )
    );
    
    RETURN QUERY SELECT 
        true,
        v_request_id,
        'Buyback request created successfully',
        v_total_buyback;
END;
$$;

-- 5. 買い取り申請処理関数（管理者用）
CREATE OR REPLACE FUNCTION process_buyback_request(
    p_request_id UUID,
    p_action TEXT, -- 'complete' or 'cancel'
    p_admin_user_id TEXT,
    p_transaction_hash TEXT DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT;
    v_manual_count INTEGER;
    v_auto_count INTEGER;
    v_status TEXT;
BEGIN
    -- リクエストの現在の状態を確認
    SELECT user_id, manual_nft_count, auto_nft_count, status
    INTO v_user_id, v_manual_count, v_auto_count, v_status
    FROM buyback_requests
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Buyback request not found';
        RETURN;
    END IF;
    
    IF v_status != 'pending' THEN
        RETURN QUERY SELECT false, 'Request already processed';
        RETURN;
    END IF;
    
    IF p_action = 'complete' THEN
        -- 買い取り完了処理
        UPDATE buyback_requests
        SET 
            status = 'completed',
            processed_by = p_admin_user_id,
            processed_at = NOW(),
            transaction_hash = p_transaction_hash,
            admin_notes = p_admin_notes,
            updated_at = NOW()
        WHERE id = p_request_id;
        
        -- pending_buybackをクリア
        UPDATE affiliate_cycle
        SET 
            pending_buyback_manual = pending_buyback_manual - v_manual_count,
            pending_buyback_auto = pending_buyback_auto - v_auto_count,
            last_updated = NOW()
        WHERE user_id = v_user_id;
        
        -- ログ記録
        INSERT INTO system_logs (
            log_type, operation, user_id, message, details
        )
        VALUES (
            'SUCCESS',
            'BUYBACK_COMPLETED',
            v_user_id,
            format('Buyback request completed by %s', p_admin_user_id),
            jsonb_build_object(
                'request_id', p_request_id,
                'transaction_hash', p_transaction_hash
            )
        );
        
        RETURN QUERY SELECT true, 'Buyback request completed successfully';
        
    ELSIF p_action = 'cancel' THEN
        -- キャンセル処理
        UPDATE buyback_requests
        SET 
            status = 'cancelled',
            processed_by = p_admin_user_id,
            processed_at = NOW(),
            admin_notes = p_admin_notes,
            updated_at = NOW()
        WHERE id = p_request_id;
        
        -- NFTを元に戻す
        UPDATE affiliate_cycle
        SET 
            manual_nft_count = manual_nft_count + v_manual_count,
            auto_nft_count = auto_nft_count + v_auto_count,
            total_nft_count = total_nft_count + (v_manual_count + v_auto_count),
            pending_buyback_manual = pending_buyback_manual - v_manual_count,
            pending_buyback_auto = pending_buyback_auto - v_auto_count,
            last_updated = NOW()
        WHERE user_id = v_user_id;
        
        -- ログ記録
        INSERT INTO system_logs (
            log_type, operation, user_id, message, details
        )
        VALUES (
            'WARNING',
            'BUYBACK_CANCELLED',
            v_user_id,
            format('Buyback request cancelled by %s', p_admin_user_id),
            jsonb_build_object(
                'request_id', p_request_id,
                'reason', p_admin_notes
            )
        );
        
        RETURN QUERY SELECT true, 'Buyback request cancelled';
    ELSE
        RETURN QUERY SELECT false, 'Invalid action';
    END IF;
END;
$$;

-- 6. 買い取り申請一覧取得関数
CREATE OR REPLACE FUNCTION get_buyback_requests(
    p_status TEXT DEFAULT NULL,
    p_user_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    id UUID,
    user_id TEXT,
    email TEXT,
    request_date TIMESTAMP WITH TIME ZONE,
    manual_nft_count INTEGER,
    auto_nft_count INTEGER,
    total_nft_count INTEGER,
    manual_buyback_amount NUMERIC,
    auto_buyback_amount NUMERIC,
    total_buyback_amount NUMERIC,
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        br.id,
        br.user_id,
        u.email,
        br.request_date,
        br.manual_nft_count,
        br.auto_nft_count,
        br.total_nft_count,
        br.manual_buyback_amount,
        br.auto_buyback_amount,
        br.total_buyback_amount,
        br.wallet_address,
        br.wallet_type,
        br.status,
        br.processed_by,
        br.processed_at,
        br.transaction_hash
    FROM buyback_requests br
    JOIN users u ON br.user_id = u.user_id
    WHERE 
        (p_status IS NULL OR br.status = p_status)
        AND (p_user_id IS NULL OR br.user_id = p_user_id)
    ORDER BY br.created_at DESC;
END;
$$;

SELECT 'NFT買い取りシステムのデータベース実装完了' as message;