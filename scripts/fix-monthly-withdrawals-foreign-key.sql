-- monthly_withdrawals に users への外部キーを追加

SELECT '=== 外部キー追加前の確認 ===' as section;

-- 既存の外部キー確認
SELECT
    tc.constraint_name,
    kcu.column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'monthly_withdrawals';

-- monthly_withdrawals の user_id が users.user_id に存在するか確認
SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT mw.user_id) as unique_users,
    COUNT(DISTINCT u.user_id) as matching_users
FROM monthly_withdrawals mw
LEFT JOIN users u ON mw.user_id = u.user_id;

SELECT '=== 外部キー制約を追加 ===' as section;

-- 外部キー制約を追加
ALTER TABLE monthly_withdrawals
ADD CONSTRAINT fk_monthly_withdrawals_user
FOREIGN KEY (user_id)
REFERENCES users(user_id)
ON DELETE CASCADE;

SELECT '=== 外部キー追加後の確認 ===' as section;

SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'monthly_withdrawals';

SELECT '=== 完了 ===' as section;
SELECT '外部キー制約を追加しました' as message;
