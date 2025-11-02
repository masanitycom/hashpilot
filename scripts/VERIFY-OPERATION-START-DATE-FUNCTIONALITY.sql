-- ========================================
-- 運用開始日ルールが実際に機能するか検証
-- ========================================

-- ① 全ユーザーの運用開始日設定状況を確認
SELECT
    '1. 全ユーザーの運用開始日設定状況' as check_type,
    COUNT(*) as total_users,
    COUNT(operation_start_date) as users_with_date,
    COUNT(*) - COUNT(operation_start_date) as users_without_date
FROM users
WHERE has_approved_nft = true;

-- ② ルール別のユーザー数を確認
SELECT
    '2. ルール別のユーザー分布' as check_type,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '①当月15日ルール'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN '②翌月1日ルール'
        ELSE '③翌月15日ルール'
    END as rule_type,
    COUNT(*) as user_count,
    MIN((p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date) as earliest_approval,
    MAX((p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date) as latest_approval
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
GROUP BY rule_type
ORDER BY rule_type;

-- ③ 運用開始日の計算が正しいか検証（サンプル10名）
SELECT
    '3. 運用開始日計算の正確性検証（サンプル）' as check_type,
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date as approved_date_jst,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day_jst,
    u.operation_start_date as actual_date,
    calculate_operation_start_date(p.admin_approved_at) as calculated_date,
    CASE
        WHEN u.operation_start_date = calculate_operation_start_date(p.admin_approved_at) THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as validation_status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
ORDER BY p.admin_approved_at DESC
LIMIT 10;

-- ④ 今日時点で運用開始済み/未開始のユーザー数
SELECT
    '4. 運用ステータス（今日時点）' as check_type,
    CASE
        WHEN operation_start_date IS NULL THEN '❌ 未設定'
        WHEN CURRENT_DATE >= operation_start_date THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前'
    END as status,
    COUNT(*) as user_count
FROM users
WHERE has_approved_nft = true
GROUP BY status
ORDER BY
    CASE
        WHEN status = '✅ 運用開始済み' THEN 1
        WHEN status = '⏳ 運用開始前' THEN 2
        ELSE 3
    END;

-- ⑤ 明日（11/1）に運用開始するユーザー数
SELECT
    '5. 明日（11/1）運用開始予定のユーザー' as check_type,
    COUNT(*) as user_count,
    STRING_AGG(u.email, ', ' ORDER BY u.email) as emails
FROM users u
WHERE u.has_approved_nft = true
  AND u.operation_start_date = '2025-11-01';

-- ⑥ 11/15に運用開始するユーザー数（10/21～10/31承認）
SELECT
    '6. 11/15運用開始予定のユーザー' as check_type,
    COUNT(*) as user_count,
    MIN((p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date) as earliest_approval,
    MAX((p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date) as latest_approval
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND u.operation_start_date = '2025-11-15';

-- ⑦ 日利処理で使用されるクエリのシミュレーション
-- （運用開始日以降のユーザーのみが対象になるか）
SELECT
    '7. 日利処理対象ユーザー（今日時点）' as check_type,
    COUNT(*) as eligible_users,
    SUM(u.total_purchases) as total_investment
FROM users u
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE;

-- ⑧ 明日（11/1）時点での日利処理対象ユーザー数
SELECT
    '8. 日利処理対象ユーザー（明日11/1時点）' as check_type,
    COUNT(*) as eligible_users,
    SUM(u.total_purchases) as total_investment
FROM users u
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2025-11-01';

-- ⑨ 運用開始日が正しく設定されていないユーザーを検出
SELECT
    '9. 設定ミスの可能性があるユーザー' as check_type,
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::date as approved_date_jst,
    u.operation_start_date as actual,
    calculate_operation_start_date(p.admin_approved_at) as expected,
    '❌ 修正が必要' as status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND u.operation_start_date != calculate_operation_start_date(p.admin_approved_at);

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 運用開始日ルールの検証が完了しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '上記の結果を確認してください：';
    RAISE NOTICE '1. 全ユーザーに運用開始日が設定されているか';
    RAISE NOTICE '2. ルール別の分布が正しいか';
    RAISE NOTICE '3. 計算が正確か（サンプル10名）';
    RAISE NOTICE '4. 運用ステータスが正しいか';
    RAISE NOTICE '5-6. 明日と11/15の運用開始者数';
    RAISE NOTICE '7-8. 日利処理対象ユーザー数';
    RAISE NOTICE '9. 設定ミスがないか';
    RAISE NOTICE '===========================================';
END $$;
