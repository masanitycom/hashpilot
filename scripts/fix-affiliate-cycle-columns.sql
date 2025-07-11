-- affiliate_cycleテーブルの欠けているカラムを修正

-- 1. affiliate_cycleテーブルの現在の構造を確認
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'affiliate_cycle' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. 必要なカラムを追加（存在しない場合のみ）
ALTER TABLE affiliate_cycle 
ADD COLUMN IF NOT EXISTS next_action TEXT DEFAULT 'usdt';

ALTER TABLE affiliate_cycle 
ADD COLUMN IF NOT EXISTS cycle_number INTEGER DEFAULT 1;

ALTER TABLE affiliate_cycle 
ADD COLUMN IF NOT EXISTS cycle_start_date DATE DEFAULT CURRENT_DATE;

-- 3. 最終的なapprove_user_nft関数（最小限の構成）
CREATE OR REPLACE FUNCTION public.approve_user_nft(
    p_purchase_id UUID,
    p_admin_email TEXT,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    status TEXT,
    message TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT;
    v_nft_quantity INTEGER;
    v_amount_usd NUMERIC;
    v_purchase_exists BOOLEAN := false;
BEGIN
    -- 購入レコードの存在確認と詳細取得
    SELECT 
        EXISTS(SELECT 1 FROM purchases WHERE id = p_purchase_id),
        user_id, 
        nft_quantity, 
        amount_usd
    INTO 
        v_purchase_exists,
        v_user_id, 
        v_nft_quantity, 
        v_amount_usd
    FROM purchases 
    WHERE id = p_purchase_id;
    
    IF NOT v_purchase_exists OR v_user_id IS NULL THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, '購入レコードが見つかりません'::TEXT;
        RETURN;
    END IF;
    
    -- 購入レコードを承認済みに更新
    UPDATE purchases 
    SET 
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        payment_status = 'payment_confirmed',
        admin_notes = COALESCE(p_admin_notes, admin_notes, '入金確認済み')
    WHERE id = p_purchase_id;
    
    -- ユーザーのNFT承認フラグとtotal_purchasesを更新
    UPDATE users 
    SET 
        has_approved_nft = true,
        total_purchases = COALESCE(total_purchases, 0) + v_amount_usd
    WHERE user_id = v_user_id;
    
    -- affiliate_cycleテーブルを更新または作成（安全に）
    INSERT INTO affiliate_cycle (
        user_id,
        phase,
        total_nft_count,
        manual_nft_count,
        auto_nft_count,
        cum_usdt,
        available_usdt
    ) VALUES (
        v_user_id,
        'USDT',
        v_nft_quantity,
        v_nft_quantity,
        0,
        0,
        0
    )
    ON CONFLICT (user_id) DO UPDATE
    SET 
        total_nft_count = COALESCE(affiliate_cycle.total_nft_count, 0) + v_nft_quantity,
        manual_nft_count = COALESCE(affiliate_cycle.manual_nft_count, 0) + v_nft_quantity;
    
    -- システムログに記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details
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
        )
    );
    
    RETURN QUERY SELECT 'SUCCESS'::TEXT, ('購入承認完了: ' || p_purchase_id::TEXT)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    -- エラーが発生した場合
    RETURN QUERY SELECT 'ERROR'::TEXT, ('エラー: ' || SQLERRM)::TEXT;
END;
$$;

-- 4. 権限設定
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO service_role;

-- 5. 更新後のテーブル構造確認
SELECT 
    'Updated affiliate_cycle columns:' as info,
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'affiliate_cycle' 
AND table_schema = 'public'
ORDER BY ordinal_position;