-- ========================================
-- 運用開始日ルールの更新
-- 旧: 承認日+15日
-- 新: 5日までに購入→当月15日、20日までに購入→翌月1日
-- ========================================

-- 1. 運用開始日を計算する関数を作成
CREATE OR REPLACE FUNCTION calculate_operation_start_date(p_approved_at TIMESTAMPTZ)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_approved_date DATE;
    v_day_of_month INTEGER;
    v_operation_start_date DATE;
BEGIN
    -- 承認日（日本時間）を取得
    v_approved_date := (p_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE;
    v_day_of_month := EXTRACT(DAY FROM v_approved_date);

    -- 運用開始日を計算
    IF v_day_of_month <= 5 THEN
        -- 5日までに購入：当月15日より運用開始
        v_operation_start_date := DATE_TRUNC('month', v_approved_date)::DATE + INTERVAL '14 days';
    ELSIF v_day_of_month <= 20 THEN
        -- 20日までに購入：翌月1日より運用開始
        v_operation_start_date := (DATE_TRUNC('month', v_approved_date) + INTERVAL '1 month')::DATE;
    ELSE
        -- 20日より後に購入：翌月1日より運用開始
        v_operation_start_date := (DATE_TRUNC('month', v_approved_date) + INTERVAL '1 month')::DATE;
    END IF;

    RETURN v_operation_start_date;
END;
$$;

-- 2. 既存ユーザーのoperation_start_dateを更新
UPDATE users u
SET operation_start_date = calculate_operation_start_date(p.admin_approved_at)
FROM (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p
WHERE u.user_id = p.user_id
  AND u.has_approved_nft = true;

-- 3. 確認: 更新されたoperation_start_dateを表示
SELECT
    u.user_id,
    u.email,
    p.admin_approved_at::date as approved_date,
    u.operation_start_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '当月15日ルール'
        ELSE '翌月1日ルール'
    END as applied_rule,
    CASE
        WHEN CURRENT_DATE >= u.operation_start_date THEN '運用開始済み'
        ELSE '運用開始前（あと' || (u.operation_start_date - CURRENT_DATE) || '日）'
    END as status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
ORDER BY u.operation_start_date DESC
LIMIT 20;

-- 4. 633DF2の確認
SELECT
    '633DF2の運用開始日確認' as section,
    u.user_id,
    u.email,
    p.admin_approved_at::date as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    u.operation_start_date,
    CASE
        WHEN CURRENT_DATE >= u.operation_start_date THEN '運用開始済み'
        ELSE '運用開始前（あと' || (u.operation_start_date - CURRENT_DATE) || '日）'
    END as status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.user_id = '633DF2';

-- 権限付与
GRANT EXECUTE ON FUNCTION calculate_operation_start_date(TIMESTAMPTZ) TO anon;
GRANT EXECUTE ON FUNCTION calculate_operation_start_date(TIMESTAMPTZ) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 運用開始日ルールを更新しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '新ルール:';
    RAISE NOTICE '  - 5日までに購入 → 当月15日より運用開始';
    RAISE NOTICE '  - 20日までに購入 → 翌月1日より運用開始';
    RAISE NOTICE '  - 20日より後に購入 → 翌月1日より運用開始';
    RAISE NOTICE '';
    RAISE NOTICE '実行内容:';
    RAISE NOTICE '  - calculate_operation_start_date() 関数を作成';
    RAISE NOTICE '  - 既存ユーザーのoperation_start_dateを更新';
    RAISE NOTICE '===========================================';
END $$;
