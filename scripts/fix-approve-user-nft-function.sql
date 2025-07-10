-- approve_user_nft関数のis_admin呼び出しを修正

-- 現在のapprove_user_nft関数の定義を確認
SELECT 
    'Current approve_user_nft function' as info,
    proname,
    prosrc
FROM pg_proc 
WHERE proname = 'approve_user_nft';

-- approve_user_nft関数を修正（明示的なキャストを追加）
CREATE OR REPLACE FUNCTION approve_user_nft(
    p_purchase_id text,
    p_admin_email text,
    p_admin_notes text DEFAULT ''
)
RETURNS TABLE(
    status text,
    message text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_check boolean := false;
    v_purchase_exists boolean := false;
    v_user_id text;
    v_amount_usd numeric;
BEGIN
    -- 管理者権限を確認（明示的なキャストを使用）
    SELECT is_admin(p_admin_email::text, NULL::uuid) INTO v_admin_check;
    
    IF NOT v_admin_check THEN
        RETURN QUERY SELECT 'ERROR'::text, '管理者権限がありません'::text;
        RETURN;
    END IF;
    
    -- 購入レコードの存在確認
    SELECT EXISTS(
        SELECT 1 FROM purchases 
        WHERE id = p_purchase_id
    ) INTO v_purchase_exists;
    
    IF NOT v_purchase_exists THEN
        RETURN QUERY SELECT 'ERROR'::text, '購入レコードが見つかりません'::text;
        RETURN;
    END IF;
    
    -- 購入レコードの詳細を取得
    SELECT user_id, amount_usd 
    INTO v_user_id, v_amount_usd
    FROM purchases 
    WHERE id = p_purchase_id;
    
    -- purchasesテーブルを更新
    UPDATE purchases 
    SET 
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        admin_notes = p_admin_notes
    WHERE id = p_purchase_id;
    
    -- usersテーブルのtotal_purchasesを更新
    UPDATE users 
    SET 
        total_purchases = COALESCE(total_purchases, 0) + v_amount_usd,
        has_approved_nft = true
    WHERE user_id = v_user_id;
    
    RETURN QUERY SELECT 'SUCCESS'::text, ('購入ID: ' || p_purchase_id || ' を承認しました')::text;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 'ERROR'::text, ('エラー: ' || SQLERRM)::text;
END;
$$;

-- 実行権限を付与
GRANT EXECUTE ON FUNCTION approve_user_nft(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION approve_user_nft(text, text, text) TO authenticated;

-- テスト実行（実際の購入IDは使わない）
SELECT 'Function updated successfully' as status;