-- approve_user_nft 関数のオーバーロード問題を修正

-- 1. 既存の全てのapprove_user_nft関数を確認
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.oid
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'approve_user_nft'
AND n.nspname = 'public';

-- 2. 全ての既存関数を削除
DROP FUNCTION IF EXISTS public.approve_user_nft(text, text, text);
DROP FUNCTION IF EXISTS public.approve_user_nft(uuid, text, text);
DROP FUNCTION IF EXISTS public.approve_user_nft(character varying, character varying, character varying);

-- 3. 統一された新しい関数を作成（UUIDのみ受け付ける）
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
    
    -- トランザクション開始
    BEGIN
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
        
        -- ユーザーのNFT承認フラグとtotal_purchasesを更新
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
        
        RETURN QUERY SELECT 'SUCCESS'::TEXT, ('購入承認完了: ' || p_purchase_id::TEXT)::TEXT;
        
    EXCEPTION WHEN OTHERS THEN
        -- エラーが発生した場合はロールバック
        RETURN QUERY SELECT 'ERROR'::TEXT, ('エラー: ' || SQLERRM)::TEXT;
    END;
END;
$$;

-- 4. 関数の権限を設定
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO service_role;

-- 5. 確認：関数が1つだけ存在することを確認
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.oid
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'approve_user_nft'
AND n.nspname = 'public';

-- 6. テスト：承認されていない購入の一覧
SELECT 
    p.id,
    p.user_id,
    u.email,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    u.has_approved_nft,
    p.created_at
FROM purchases p
LEFT JOIN users u ON u.user_id = p.user_id
WHERE p.admin_approved = false
    AND p.payment_status = 'payment_sent'
ORDER BY p.created_at DESC;