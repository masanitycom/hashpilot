-- 承認日変更機能の追加
-- 管理者が購入承認日を変更できる機能

-- 1. パフォーマンス向上のためのインデックス追加
CREATE INDEX IF NOT EXISTS idx_purchases_admin_approved_at 
ON purchases(admin_approved_at DESC) 
WHERE admin_approved = true;

-- 2. 承認日変更関数の作成
CREATE OR REPLACE FUNCTION modify_purchase_approval_date(
    p_purchase_id TEXT,
    p_new_approval_date TIMESTAMP WITH TIME ZONE,
    p_admin_email TEXT,
    p_reason TEXT DEFAULT ''
)
RETURNS TABLE (
    status TEXT,
    message TEXT,
    old_date TIMESTAMP WITH TIME ZONE,
    new_date TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_approval_date TIMESTAMP WITH TIME ZONE;
    v_purchase_record RECORD;
    v_user_created_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (
        SELECT 1 FROM admins WHERE email = p_admin_email
    ) AND p_admin_email NOT IN ('basarasystems@gmail.com', 'support@dshsupport.biz') THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            '管理者権限が必要です'::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- 購入記録の存在確認と現在の承認日取得
    SELECT admin_approved_at, admin_approved, user_id, created_at 
    INTO v_purchase_record
    FROM purchases 
    WHERE id = p_purchase_id::UUID;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            '購入記録が見つかりません'::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- 承認済みでない場合のエラー
    IF NOT v_purchase_record.admin_approved THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            '未承認の購入記録の承認日は変更できません'::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- ユーザーアカウント作成日取得
    SELECT created_at INTO v_user_created_at
    FROM users 
    WHERE user_id = v_purchase_record.user_id;

    -- 入力値検証
    IF p_new_approval_date > NOW() THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            '未来の日付は設定できません'::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    IF p_new_approval_date < v_user_created_at THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            'ユーザー登録日より前の日付は設定できません'::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    IF p_new_approval_date < v_purchase_record.created_at THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT,
            '購入申請日より前の日付は設定できません'::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- 現在の承認日を保存
    v_old_approval_date := v_purchase_record.admin_approved_at;

    -- 承認日を更新
    UPDATE purchases 
    SET 
        admin_approved_at = p_new_approval_date,
        admin_notes = COALESCE(admin_notes, '') || 
            E'\n[' || NOW()::DATE || '] 承認日変更: ' || 
            COALESCE(v_old_approval_date::DATE::TEXT, 'NULL') || ' → ' || 
            p_new_approval_date::DATE || ' (変更者: ' || p_admin_email || 
            CASE WHEN p_reason != '' THEN ', 理由: ' || p_reason ELSE '' END || ')',
        updated_at = NOW()
    WHERE id = p_purchase_id::UUID;

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
        'modify_approval_date',
        v_purchase_record.user_id,
        '購入承認日を変更しました',
        jsonb_build_object(
            'purchase_id', p_purchase_id,
            'old_approval_date', v_old_approval_date,
            'new_approval_date', p_new_approval_date,
            'admin_email', p_admin_email,
            'reason', p_reason
        ),
        NOW()
    );

    RETURN QUERY SELECT 
        'SUCCESS'::TEXT,
        '承認日を正常に変更しました'::TEXT,
        v_old_approval_date,
        p_new_approval_date;
END;
$$;

-- 3. 関数の権限設定
GRANT EXECUTE ON FUNCTION modify_purchase_approval_date(TEXT, TIMESTAMP WITH TIME ZONE, TEXT, TEXT) TO authenticated;

-- 4. 動作確認用のテスト（コメントアウト）
/*
-- テスト用クエリ例
SELECT * FROM modify_purchase_approval_date(
    '購入ID',
    '2024-01-15 10:00:00+09'::TIMESTAMP WITH TIME ZONE,
    'admin@example.com',
    '承認漏れのため遡って設定'
);
*/

-- 5. 完了メッセージ
SELECT 
    '✅ 承認日変更機能が追加されました' as status,
    'modify_purchase_approval_date関数を使用して承認日を変更できます' as message;