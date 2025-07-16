-- NFT配布状況を管理するためのフィールドを追加
-- 慎重に既存データに影響を与えないよう実装

-- =================================
-- 1. usersテーブルにNFT配布状況フィールドを追加
-- =================================

-- NFT配布済みフラグ
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS nft_distributed BOOLEAN DEFAULT FALSE;

-- NFT配布日時
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS nft_distributed_at TIMESTAMP WITH TIME ZONE;

-- NFT配布を実行した管理者
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS nft_distributed_by TEXT;

-- NFT配布に関する備考
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS nft_distribution_notes TEXT;

-- =================================
-- 2. インデックスを追加（検索性能向上）
-- =================================

-- NFT配布状況での検索を高速化
CREATE INDEX IF NOT EXISTS idx_users_nft_distributed 
ON users(nft_distributed);

-- NFT配布日時での検索を高速化
CREATE INDEX IF NOT EXISTS idx_users_nft_distributed_at 
ON users(nft_distributed_at);

-- =================================
-- 3. NFT配布状況を更新する安全な関数を作成
-- =================================

CREATE OR REPLACE FUNCTION update_nft_distribution_status(
    p_user_id TEXT,
    p_is_distributed BOOLEAN,
    p_admin_user_id TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    user_id TEXT,
    previous_status BOOLEAN,
    new_status BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_exists BOOLEAN;
    v_previous_status BOOLEAN;
    v_admin_email TEXT;
BEGIN
    -- ユーザーの存在確認
    SELECT EXISTS(
        SELECT 1 FROM users WHERE users.user_id = p_user_id
    ), nft_distributed
    INTO v_user_exists, v_previous_status
    FROM users 
    WHERE users.user_id = p_user_id;
    
    IF NOT v_user_exists THEN
        RETURN QUERY SELECT 
            FALSE,
            'ユーザーが見つかりません',
            p_user_id,
            FALSE,
            FALSE;
        RETURN;
    END IF;
    
    -- 管理者の確認
    SELECT email INTO v_admin_email
    FROM users 
    WHERE users.user_id = p_admin_user_id;
    
    -- NFT配布状況を更新
    UPDATE users SET
        nft_distributed = p_is_distributed,
        nft_distributed_at = CASE 
            WHEN p_is_distributed THEN NOW()
            ELSE NULL
        END,
        nft_distributed_by = CASE 
            WHEN p_is_distributed THEN COALESCE(v_admin_email, p_admin_user_id)
            ELSE NULL
        END,
        nft_distribution_notes = CASE 
            WHEN p_is_distributed THEN p_notes
            ELSE NULL
        END,
        updated_at = NOW()
    WHERE users.user_id = p_user_id;
    
    -- システムログに記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'INFO',
        'nft_distribution_update',
        p_user_id,
        CASE 
            WHEN p_is_distributed THEN 'NFT配布完了に設定されました'
            ELSE 'NFT配布状況が未配布に変更されました'
        END,
        jsonb_build_object(
            'admin_user_id', p_admin_user_id,
            'previous_status', v_previous_status,
            'new_status', p_is_distributed,
            'notes', p_notes
        ),
        NOW()
    );
    
    RETURN QUERY SELECT 
        TRUE,
        CASE 
            WHEN p_is_distributed THEN 'NFT配布完了に設定しました'
            ELSE 'NFT配布状況を未配布に変更しました'
        END,
        p_user_id,
        v_previous_status,
        p_is_distributed;
END;
$$;

-- =================================
-- 4. NFT配布状況を取得する関数
-- =================================

CREATE OR REPLACE FUNCTION get_nft_distribution_summary()
RETURNS TABLE (
    total_users INTEGER,
    nft_distributed_users INTEGER,
    nft_pending_users INTEGER,
    distribution_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_users,
        COUNT(CASE WHEN nft_distributed = TRUE THEN 1 END)::INTEGER as nft_distributed_users,
        COUNT(CASE WHEN nft_distributed = FALSE OR nft_distributed IS NULL THEN 1 END)::INTEGER as nft_pending_users,
        ROUND(
            (COUNT(CASE WHEN nft_distributed = TRUE THEN 1 END)::NUMERIC / NULLIF(COUNT(*)::NUMERIC, 0)) * 100,
            2
        ) as distribution_rate
    FROM users
    WHERE email NOT IN ('basarasystems@gmail.com', 'support@dshsupport.biz'); -- 管理者アカウントを除外
END;
$$;

-- =================================
-- 5. 実行権限を設定
-- =================================

GRANT EXECUTE ON FUNCTION update_nft_distribution_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_nft_distribution_summary TO authenticated;

-- =================================
-- 6. 現在の状況を確認
-- =================================

-- 新しいフィールドの構造確認
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('nft_distributed', 'nft_distributed_at', 'nft_distributed_by', 'nft_distribution_notes')
ORDER BY column_name;

-- NFT配布状況の統計
SELECT * FROM get_nft_distribution_summary();

-- NFT配布状況の詳細（上位10件）
SELECT 
    user_id,
    email,
    nft_distributed,
    nft_distributed_at,
    nft_distributed_by,
    nft_receive_address,
    total_purchases,
    created_at
FROM users
WHERE email NOT IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
ORDER BY created_at DESC
LIMIT 10;

-- =================================
-- 7. 既存データの整合性チェック
-- =================================

-- NFT受取アドレスが設定されているユーザーの確認
SELECT 
    '設定済みアドレス' as status,
    COUNT(*) as count
FROM users 
WHERE nft_receive_address IS NOT NULL 
AND nft_receive_address != ''
AND email NOT IN ('basarasystems@gmail.com', 'support@dshsupport.biz')

UNION ALL

SELECT 
    '未設定アドレス' as status,
    COUNT(*) as count
FROM users 
WHERE (nft_receive_address IS NULL OR nft_receive_address = '')
AND email NOT IN ('basarasystems@gmail.com', 'support@dshsupport.biz');