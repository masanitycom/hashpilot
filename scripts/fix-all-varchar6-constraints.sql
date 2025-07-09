-- すべてのVARCHAR(6)制限を修正

-- 1. user_idがVARCHAR(6)の場合は修正
DO $$
BEGIN
    -- user_idの型を確認して修正
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'user_id' 
        AND character_maximum_length = 6
    ) THEN
        ALTER TABLE users ALTER COLUMN user_id TYPE TEXT;
        RAISE NOTICE 'user_id column type changed to TEXT';
    END IF;
    
    -- referrer_user_idの型を確認して修正
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'referrer_user_id' 
        AND character_maximum_length = 6
    ) THEN
        ALTER TABLE users ALTER COLUMN referrer_user_id TYPE TEXT;
        RAISE NOTICE 'referrer_user_id column type changed to TEXT';
    END IF;
END $$;

-- 2. 修正結果確認
SELECT 
    'fixed_columns' as status,
    column_name,
    data_type,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('user_id', 'referrer_user_id', 'coinw_uid');
