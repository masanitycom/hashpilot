-- 管理者権限修正とシステム設定テーブル更新（正しい順序）

-- 1. 管理者テーブルが存在することを確認
CREATE TABLE IF NOT EXISTS admins (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    user_id VARCHAR(6),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. システム設定テーブルを作成（BEP20/TRC20対応）
CREATE TABLE IF NOT EXISTS system_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    usdt_address_bep20 TEXT,
    usdt_address_trc20 TEXT,
    nft_price DECIMAL(10,2) DEFAULT 1100.00,
    maintenance_mode BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- 3. 既存データがある場合の処理
DO $$
BEGIN
    -- 古いusdt_addressカラムが存在する場合の処理
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_settings' 
        AND column_name = 'usdt_address'
    ) THEN
        -- 既存データをBEP20に移行
        UPDATE system_settings 
        SET usdt_address_bep20 = usdt_address 
        WHERE usdt_address IS NOT NULL 
        AND usdt_address_bep20 IS NULL;
        
        -- 古いカラムを削除
        ALTER TABLE system_settings DROP COLUMN IF EXISTS usdt_address;
        
        RAISE NOTICE 'Migrated existing usdt_address to usdt_address_bep20';
    END IF;
END
$$;

-- 4. デフォルト設定を挿入（存在しない場合のみ）
INSERT INTO system_settings (id, nft_price, maintenance_mode)
SELECT 1, 1100.00, FALSE
WHERE NOT EXISTS (SELECT 1 FROM system_settings WHERE id = 1);

-- 5. 管理者権限チェック関数の改善
CREATE OR REPLACE FUNCTION is_admin(user_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_exists BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM admins 
        WHERE email = user_email 
        AND is_active = true
    ) INTO admin_exists;
    
    RETURN admin_exists;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;

-- 6. RLSポリシーの設定
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- 管理者のみがシステム設定を変更可能
DROP POLICY IF EXISTS "Admin can manage system settings" ON system_settings;
CREATE POLICY "Admin can manage system settings" ON system_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE email = auth.jwt() ->> 'email' 
            AND is_active = true
        )
    );

-- 全ユーザーがシステム設定を読み取り可能
DROP POLICY IF EXISTS "Everyone can read system settings" ON system_settings;
CREATE POLICY "Everyone can read system settings" ON system_settings
    FOR SELECT USING (true);

-- 7. 確認クエリ
SELECT 
    'System Settings Table Structure' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'system_settings'
ORDER BY ordinal_position;

-- 8. 現在の設定を表示
SELECT 
    'Current System Settings' as check_type,
    *
FROM system_settings;

-- 9. 管理者一覧を表示
SELECT 
    'Current Admins' as check_type,
    email,
    is_active,
    created_at
FROM admins
ORDER BY created_at;
