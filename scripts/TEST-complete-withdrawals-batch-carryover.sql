-- ========================================
-- complete_withdrawals_batch 繰越処理テスト
-- ========================================

-- ========================================
-- STEP 1: 現在の状態確認
-- ========================================
SELECT '=== STEP 1: 繰越がありそうなユーザーを確認 ===' as step;

-- 複数月のpending/on_holdを持つユーザー
SELECT
    user_id,
    array_agg(withdrawal_month ORDER BY withdrawal_month) as months,
    array_agg(status ORDER BY withdrawal_month) as statuses,
    array_agg(total_amount ORDER BY withdrawal_month) as amounts,
    COUNT(*) as month_count
FROM monthly_withdrawals
WHERE status IN ('pending', 'on_hold')
GROUP BY user_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 10;

-- ========================================
-- STEP 2: テスト対象を選定
-- ========================================
SELECT '=== STEP 2: テスト対象の詳細 ===' as step;

-- 11月と12月の両方がpending/on_holdのユーザー
SELECT
    mw11.user_id,
    mw11.id as nov_id,
    mw11.total_amount as nov_amount,
    mw11.status as nov_status,
    mw12.id as dec_id,
    mw12.total_amount as dec_amount,
    mw12.status as dec_status
FROM monthly_withdrawals mw11
JOIN monthly_withdrawals mw12
    ON mw11.user_id = mw12.user_id
WHERE mw11.withdrawal_month = '2025-11-01'
  AND mw12.withdrawal_month = '2025-12-01'
  AND mw11.status IN ('pending', 'on_hold')
  AND mw12.status IN ('pending', 'on_hold')
LIMIT 5;

-- ========================================
-- STEP 3: テスト実行（11月を完了しようとする → エラーになるはず）
-- ========================================
SELECT '=== STEP 3: 11月を完了しようとする（エラーになるはず） ===' as step;

-- 上記で見つかった最初のユーザーの11月IDを使う
-- 実際のIDに置き換えてください
/*
SELECT * FROM complete_withdrawals_batch(
    ARRAY['ここに11月のIDを入れる']::UUID[]
);
*/

-- ========================================
-- STEP 4: テスト実行（12月を完了 → 11月も自動完了になるはず）
-- ========================================
SELECT '=== STEP 4: 12月を完了する（11月も自動完了になるはず） ===' as step;

-- 上記で見つかった最初のユーザーの12月IDを使う
-- 実際のIDに置き換えてください
/*
SELECT * FROM complete_withdrawals_batch(
    ARRAY['ここに12月のIDを入れる']::UUID[]
);
*/

-- ========================================
-- STEP 5: 結果確認
-- ========================================
SELECT '=== STEP 5: 結果確認用クエリ ===' as step;

-- テスト後にこれを実行して確認
/*
SELECT
    user_id,
    withdrawal_month,
    total_amount,
    status,
    notes,
    completed_at
FROM monthly_withdrawals
WHERE user_id = 'テストしたユーザーID'
ORDER BY withdrawal_month;
*/

-- ========================================
-- 注意: 実際にテストする場合
-- ========================================
SELECT '=== 注意事項 ===' as note;
SELECT 'STEP 2で見つかったユーザーのIDを使って、STEP 3と4のコメントを外して実行してください' as instruction;
SELECT 'テストは本番データに影響するので、テスト用ユーザーで行うか、慎重に選んでください' as warning;
