-- 購入レコード削除関数を作成
CREATE OR REPLACE FUNCTION delete_purchase_record(
    purchase_id UUID,
    admin_email TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (
        SELECT 1 FROM admins 
        WHERE email = admin_email AND is_active = true
    ) THEN
        RAISE EXCEPTION '管理者権限がありません';
    END IF;

    -- 購入レコードが存在するかチェック
    IF NOT EXISTS (
        SELECT 1 FROM purchases WHERE id = purchase_id
    ) THEN
        RAISE EXCEPTION '購入レコードが見つかりません';
    END IF;

    -- 購入レコードを削除
    DELETE FROM purchases WHERE id = purchase_id;

    RETURN TRUE;
END;
$$;

-- 関数の実行権限を設定
GRANT EXECUTE ON FUNCTION delete_purchase_record(UUID, TEXT) TO authenticated;

-- 確認用クエリ
SELECT 'delete_purchase_record function created successfully' as status;
