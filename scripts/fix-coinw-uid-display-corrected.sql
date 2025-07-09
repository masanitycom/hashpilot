-- CoinW UID表示問題の修正（修正版）

-- 1. admin_purchases_viewを再作成（正しいJOINで）
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,  -- usersテーブルからCoinW UIDを取得
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
LEFT JOIN users u ON p.user_id = u.user_id
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
    referrer_id := NEW.raw_user_meta_data->>'referrer_user_id';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    
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
        NEW.raw_user_meta_data->>'full_name',
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
SET coinw_uid = (
    SELECT raw_user_meta_data->>'coinw_uid' 
    FROM auth.users 
    WHERE auth.users.id = users.id
)
WHERE coinw_uid IS NULL 
AND EXISTS (
    SELECT 1 FROM auth.users 
    WHERE auth.users.id = users.id 
    AND raw_user_meta_data->>'coinw_uid' IS NOT NULL
);

-- 4. 特定ユーザーのCoinW UID手動設定（テスト用）
-- 該当ユーザーのCoinW UIDが空の場合の緊急対応
DO $$
DECLARE
    auth_coinw_uid TEXT;
BEGIN
    -- auth.usersからCoinW UIDを取得
    SELECT raw_user_meta_data->>'coinw_uid' INTO auth_coinw_uid
    FROM auth.users 
    WHERE email = 'masataka.tak+22@gmail.com';
    
    -- usersテーブルを更新
    IF auth_coinw_uid IS NOT NULL THEN
        UPDATE users 
        SET coinw_uid = auth_coinw_uid
        WHERE email = 'masataka.tak+22@gmail.com';
        
        RAISE NOTICE 'Updated CoinW UID for masataka.tak+22@gmail.com: %', auth_coinw_uid;
    ELSE
        RAISE NOTICE 'No CoinW UID found in auth.users for masataka.tak+22@gmail.com';
    END IF;
END $$;
