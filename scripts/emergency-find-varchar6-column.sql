-- VARCHAR(6)制限がまだ残っている列を特定

-- 1. すべてのテーブルでVARCHAR(6)の列を検索
SELECT 
    'varchar6_columns' as check_type,
    table_name,
    column_name,
    data_type,
    character_maximum_length
FROM information_schema.columns 
WHERE character_maximum_length = 6
AND table_schema = 'public';

-- 2. usersテーブルの全列情報
SELECT 
    'users_table_columns' as check_type,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 3. 制約情報
SELECT 
    'table_constraints' as check_type,
    constraint_name,
    constraint_type,
    table_name
FROM information_schema.table_constraints 
WHERE table_name = 'users';

-- 4. CHECK制約の詳細
SELECT 
    'check_constraints' as check_type,
    constraint_name,
    check_clause
FROM information_schema.check_constraints 
WHERE constraint_name IN (
    SELECT constraint_name 
    FROM information_schema.table_constraints 
    WHERE table_name = 'users' AND constraint_type = 'CHECK'
);
