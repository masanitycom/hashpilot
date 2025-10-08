-- ========================================
-- usersテーブルにoperation_start_dateカラムを追加
-- ========================================

-- 1. カラムを追加（既に存在する場合はスキップ）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users'
        AND column_name = 'operation_start_date'
    ) THEN
        ALTER TABLE users
        ADD COLUMN operation_start_date DATE;

        RAISE NOTICE 'カラム operation_start_date を追加しました';
    ELSE
        RAISE NOTICE 'カラム operation_start_date は既に存在します';
    END IF;
END $$;

-- 2. カラムにコメントを追加
COMMENT ON COLUMN users.operation_start_date IS '運用開始日（新ルール: 5日までに購入→当月15日、20日までに購入→翌月1日）';

-- 3. 確認
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name = 'operation_start_date';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ operation_start_dateカラムを追加しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. update-operation-start-date-rule.sql を実行';
    RAISE NOTICE '  2. update-daily-yield-with-new-operation-rule.sql を実行';
    RAISE NOTICE '===========================================';
END $$;
