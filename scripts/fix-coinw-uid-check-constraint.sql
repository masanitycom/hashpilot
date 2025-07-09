-- CoinW UIDのCHECK制約を完全に削除

-- 1. CHECK制約を確認
SELECT 
    'check_constraints' as info_type,
    constraint_name,
    check_clause
FROM information_schema.check_constraints 
WHERE constraint_name LIKE '%coinw%';

-- 2. usersテーブルの制約を確認
SELECT 
    'table_constraints' as info_type,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'users' AND constraint_name LIKE '%coinw%';

-- 3. CHECK制約を削除
DO $$
DECLARE
    constraint_rec RECORD;
BEGIN
    FOR constraint_rec IN 
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE table_name = 'users' 
        AND constraint_type = 'CHECK' 
        AND constraint_name LIKE '%coinw%'
    LOOP
        EXECUTE 'ALTER TABLE users DROP CONSTRAINT ' || constraint_rec.constraint_name;
    END LOOP;
END $$;

-- 4. 列の型を確認
SELECT 
    'column_info_after_fix' as info_type,
    column_name,
    data_type,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'coinw_uid';
