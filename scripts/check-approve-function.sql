-- approve_user_nft 関数の存在確認と修正

-- 1. 現在の関数を確認
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'approve_user_nft';

-- 2. 関数が存在しない場合、または正しく動作しない場合は再作成
DROP FUNCTION IF EXISTS approve_user_nft(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION approve_user_nft(
    p_purchase_id UUID,
    p_admin_email TEXT,
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
    v_user_id TEXT;
    v_nft_quantity INTEGER;
    v_amount_usd NUMERIC;
BEGIN
    -- 購入情報を取得
    SELECT user_id, nft_quantity, amount_usd 
    INTO v_user_id, v_nft_quantity, v_amount_usd
    FROM purchases 
    WHERE id = p_purchase_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, '購入レコードが見つかりません';
        RETURN;
    END IF;
    
    -- 購入レコードを承認済みに更新
    UPDATE purchases 
    SET 
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        payment_status = 'payment_confirmed',
        admin_notes = COALESCE(p_admin_notes, admin_notes, '入金確認済み'),
        updated_at = NOW()
    WHERE id = p_purchase_id;
    
    -- ユーザーのNFT承認フラグを更新
    UPDATE users 
    SET 
        has_approved_nft = true,
        total_purchases = COALESCE(total_purchases, 0) + v_amount_usd,
        updated_at = NOW()
    WHERE user_id = v_user_id;
    
    -- affiliate_cycleテーブルを更新または作成
    INSERT INTO affiliate_cycle (
        user_id,
        phase,
        total_nft_count,
        manual_nft_count,
        auto_nft_count,
        cum_usdt,
        available_usdt,
        next_action,
        cycle_number,
        cycle_start_date,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        'USDT',
        v_nft_quantity,
        v_nft_quantity,
        0,
        0,
        0,
        'usdt',
        1,
        CURRENT_DATE,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET 
        total_nft_count = affiliate_cycle.total_nft_count + v_nft_quantity,
        manual_nft_count = affiliate_cycle.manual_nft_count + v_nft_quantity,
        updated_at = NOW();
    
    -- システムログに記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'SUCCESS',
        'nft_purchase_approved',
        v_user_id,
        'NFT購入が承認されました',
        jsonb_build_object(
            'purchase_id', p_purchase_id,
            'nft_quantity', v_nft_quantity,
            'amount_usd', v_amount_usd,
            'approved_by', p_admin_email,
            'admin_notes', p_admin_notes
        ),
        NOW()
    );
    
    RETURN QUERY SELECT true, 'NFT購入を承認し、ユーザーを有効化しました';
END;
$$;

-- 3. 関数の権限を設定
GRANT EXECUTE ON FUNCTION approve_user_nft(UUID, TEXT, TEXT) TO authenticated;

-- 4. テスト用クエリ - 承認されていない購入を確認
SELECT 
    p.id,
    p.user_id,
    u.email,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    u.has_approved_nft
FROM purchases p
JOIN users u ON u.user_id = p.user_id
WHERE p.admin_approved = false
    AND p.payment_status = 'payment_sent'
ORDER BY p.created_at DESC
LIMIT 10;