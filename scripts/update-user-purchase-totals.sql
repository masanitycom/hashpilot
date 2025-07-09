-- ユーザーの購入合計を正しく更新する関数を作成

CREATE OR REPLACE FUNCTION update_user_purchase_total(target_user_id TEXT)
RETURNS VOID AS $$
DECLARE
    total_amount NUMERIC;
BEGIN
    -- 承認済み購入の合計を計算
    SELECT COALESCE(SUM(amount_usd), 0) INTO total_amount
    FROM purchases 
    WHERE user_id = target_user_id AND admin_approved = TRUE;
    
    -- usersテーブルを更新
    UPDATE users 
    SET total_purchases = total_amount
    WHERE user_id = target_user_id;
    
    RAISE NOTICE 'Updated user % total purchases to %', target_user_id, total_amount;
END;
$$ LANGUAGE plpgsql;

-- 承認関数を修正して購入合計も更新
CREATE OR REPLACE FUNCTION approve_user_nft(
    purchase_id UUID,
    admin_email TEXT,
    admin_notes_text TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    target_user_id TEXT;
    purchase_exists BOOLEAN;
BEGIN
    -- 管理者権限チェック
    IF NOT is_admin(admin_email) THEN
        RAISE EXCEPTION '管理者権限がありません';
    END IF;
    
    -- 購入レコードの存在確認とuser_id取得
    SELECT user_id INTO target_user_id
    FROM purchases 
    WHERE id = purchase_id AND admin_approved = FALSE;
    
    IF target_user_id IS NULL THEN
        RAISE EXCEPTION '承認対象の購入が見つかりません';
    END IF;
    
    -- 購入を承認
    UPDATE purchases 
    SET 
        admin_approved = TRUE,
        admin_approved_at = NOW(),
        admin_approved_by = admin_email,
        admin_notes = admin_notes_text,
        payment_status = 'approved'
    WHERE id = purchase_id;
    
    -- ユーザーのNFT所有状況を更新
    UPDATE users 
    SET 
        has_approved_nft = TRUE,
        first_nft_approved_at = COALESCE(first_nft_approved_at, NOW())
    WHERE user_id = target_user_id;
    
    -- 購入合計を更新
    PERFORM update_user_purchase_total(target_user_id);
    
    RAISE NOTICE 'NFT承認完了: user_id=%, admin=%', target_user_id, admin_email;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 既存の承認済み購入がある場合、購入合計を更新
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN 
        SELECT DISTINCT user_id 
        FROM purchases 
        WHERE admin_approved = TRUE
    LOOP
        PERFORM update_user_purchase_total(user_record.user_id);
    END LOOP;
END $$;

-- 現在の状況を確認
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    COUNT(p.id) as purchase_count,
    SUM(CASE WHEN p.admin_approved THEN p.amount_usd ELSE 0 END) as approved_total
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id
GROUP BY u.user_id, u.email, u.total_purchases
ORDER BY u.created_at DESC;
