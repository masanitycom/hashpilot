-- ========================================
-- 運用開始日ルールの修正（正しいルール）
-- 修正理由: 21日～翌月5日の購入が「翌月15日」になっていなかった
-- ========================================

-- 正しいルール:
-- ① 毎月5日までに購入 → 当月15日より運用開始
-- ② 毎月6日～20日に購入 → 翌月1日より運用開始
-- ③ 毎月21日～翌月5日に購入 → 翌月15日より運用開始

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
        -- ① 5日までに購入：当月15日より運用開始
        v_operation_start_date := DATE_TRUNC('month', v_approved_date)::DATE + INTERVAL '14 days';
    ELSIF v_day_of_month <= 20 THEN
        -- ② 6日～20日に購入：翌月1日より運用開始
        v_operation_start_date := (DATE_TRUNC('month', v_approved_date) + INTERVAL '1 month')::DATE;
    ELSE
        -- ③ 21日～月末に購入：翌月15日より運用開始
        v_operation_start_date := (DATE_TRUNC('month', v_approved_date) + INTERVAL '1 month')::DATE + INTERVAL '14 days';
    END IF;

    RETURN v_operation_start_date;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION calculate_operation_start_date(TIMESTAMPTZ) TO anon;
GRANT EXECUTE ON FUNCTION calculate_operation_start_date(TIMESTAMPTZ) TO authenticated;

-- 既存ユーザーのoperation_start_dateを再計算して更新
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

-- 確認: 更新されたoperation_start_dateを表示
SELECT
    u.user_id,
    u.email,
    p.admin_approved_at::date as approved_date,
    u.operation_start_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '①当月15日ルール'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN '②翌月1日ルール'
        ELSE '③翌月15日ルール'
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
LIMIT 50;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 運用開始日ルールを修正しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '正しいルール:';
    RAISE NOTICE '  ① 毎月5日までに購入 → 当月15日より運用開始';
    RAISE NOTICE '  ② 毎月6日～20日に購入 → 翌月1日より運用開始';
    RAISE NOTICE '  ③ 毎月21日～翌月5日に購入 → 翌月15日より運用開始';
    RAISE NOTICE '';
    RAISE NOTICE '実行内容:';
    RAISE NOTICE '  - calculate_operation_start_date() 関数を修正';
    RAISE NOTICE '  - 既存ユーザーのoperation_start_dateを再計算';
    RAISE NOTICE '===========================================';
END $$;
