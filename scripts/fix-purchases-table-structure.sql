-- purchasesテーブルの構造を確認し、必要なカラムを追加

-- 1. purchasesテーブルの現在の構造を確認
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'purchases' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. updated_atカラムが存在しない場合は追加
ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. created_atカラムも念のため確認・追加
ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- 4. approve_user_nft関数を修正（updated_atを使わないバージョン）
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
        -- 購入レコードを承認済みに更新（updated_atを除外）
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

-- 5. 実行権限を付与
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.approve_user_nft(UUID, TEXT, TEXT) TO service_role;

-- 6. テスト実行 - 最初の未承認購入を確認
SELECT 
    p.id,
    p.user_id,
    u.email,
    p.nft_quantity,
    p.amount_usd,
    p.admin_approved,
    u.has_approved_nft
FROM purchases p
LEFT JOIN users u ON u.user_id = p.user_id
WHERE p.admin_approved = false
    AND p.payment_status = 'payment_sent'
ORDER BY p.created_at DESC
LIMIT 1;