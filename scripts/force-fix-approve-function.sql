-- 強制的にapprove_user_nft関数を修正

-- 全ての関数を強制削除
DROP FUNCTION IF EXISTS approve_user_nft(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS approve_user_nft(uuid, text, text) CASCADE;

-- 1つの明確な関数を作成
CREATE FUNCTION approve_user_nft(
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
    v_purchase_exists boolean := false;
    v_user_id text;
    v_amount_usd numeric;
BEGIN
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
    
    RETURN QUERY SELECT 'SUCCESS'::text, ('購入承認完了: ' || p_purchase_id)::text;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 'ERROR'::text, ('エラー: ' || SQLERRM)::text;
END;
$$;

-- 実行権限を付与
GRANT EXECUTE ON FUNCTION approve_user_nft(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION approve_user_nft(text, text, text) TO authenticated;

-- 確認
SELECT 
    'Function count' as info,
    COUNT(*) as count
FROM pg_proc 
WHERE proname = 'approve_user_nft';

-- テスト実行
SELECT 'Function test' as info, approve_user_nft('test', 'test@test.com', 'test') as result;