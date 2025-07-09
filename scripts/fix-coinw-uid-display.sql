-- CoinW UID表示問題の修正

-- 1. admin_purchases_viewを再作成（CoinW UIDを確実に含める）
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,  -- 確実にCoinW UIDを含める
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes,
    p.created_at,
    p.confirmed_at,
    p.completed_at,
    u.has_approved_nft
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id  -- LEFT JOINで確実に結合
ORDER BY p.created_at DESC;

-- 2. 新規登録時のCoinW UID保存を確実にするトリガー修正
CREATE OR REPLACE FUNCTION handle_new_user_with_metadata()
RETURNS TRIGGER AS $$
DECLARE
    short_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
BEGIN
    -- ショートユーザーIDを生成
    short_user_id := generate_short_user_id();
    
    -- メタデータからreferrer_user_idとcoinw_uidを取得
    referrer_id := COALESCE(
        NEW.raw_user_meta_data->>'referrer_user_id',
        NEW.user_metadata->>'referrer_user_id'
    );
    
    coinw_uid_value := COALESCE(
        NEW.raw_user_meta_data->>'coinw_uid',
        NEW.user_metadata->>'coinw_uid'
    );
    
    -- usersテーブルにレコードを挿入
    INSERT INTO public.users (
        id,
        user_id,
        email,
        full_name,
        referrer_user_id,
        coinw_uid,  -- CoinW UIDを確実に保存
        created_at,
        updated_at,
        is_active
    ) VALUES (
        NEW.id,
        short_user_id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.user_metadata->>'full_name'),
        referrer_id,
        coinw_uid_value,  -- CoinW UIDを確実に保存
        NOW(),
        NOW(),
        true
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- エラーログを記録
        RAISE LOG 'Error in handle_new_user_with_metadata: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 既存ユーザーのCoinW UIDをauth.usersから同期
UPDATE users 
SET coinw_uid = COALESCE(
    (SELECT raw_user_meta_data->>'coinw_uid' FROM auth.users WHERE auth.users.id = users.id),
    (SELECT user_metadata->>'coinw_uid' FROM auth.users WHERE auth.users.id = users.id)
)
WHERE coinw_uid IS NULL 
AND EXISTS (
    SELECT 1 FROM auth.users 
    WHERE auth.users.id = users.id 
    AND (
        raw_user_meta_data->>'coinw_uid' IS NOT NULL 
        OR user_metadata->>'coinw_uid' IS NOT NULL
    )
);
