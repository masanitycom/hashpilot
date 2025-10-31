-- ========================================
-- 【緊急】10/21～10/31購入ユーザーの運用開始日設定
-- 対象: 16名のユーザー
-- ========================================

-- まず、関数を修正（念のため再実行）
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

-- 10/21～10/31に承認されたユーザーの運用開始日を強制的に設定
UPDATE users u
SET operation_start_date = '2025-11-15'
FROM (
    SELECT DISTINCT user_id
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
      AND (admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date >= '2025-10-21'
      AND (admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date <= '2025-10-31'
) p
WHERE u.user_id = p.user_id;

-- 確認: 更新されたユーザーを表示
SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date as approved_date_jst,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    u.operation_start_date,
    u.has_approved_nft,
    CASE
        WHEN u.operation_start_date = '2025-11-15' THEN '✅ 正しく設定済み'
        WHEN u.operation_start_date IS NULL THEN '❌ まだNULL'
        ELSE '⚠️ 他の日付: ' || u.operation_start_date::text
    END as status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date >= '2025-10-21'
  AND (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date <= '2025-10-31'
ORDER BY p.admin_approved_at DESC;

-- 完了メッセージ
DO $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_updated_count
    FROM users u
    INNER JOIN (
        SELECT DISTINCT user_id
        FROM purchases
        WHERE admin_approved = true
          AND admin_approved_at IS NOT NULL
          AND (admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date >= '2025-10-21'
          AND (admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date <= '2025-10-31'
    ) p ON u.user_id = p.user_id
    WHERE u.operation_start_date = '2025-11-15';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 10/21～10/31購入ユーザーの運用開始日を設定';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '更新件数: % 名', v_updated_count;
    RAISE NOTICE '運用開始日: 2025-11-15';
    RAISE NOTICE '===========================================';
END $$;
