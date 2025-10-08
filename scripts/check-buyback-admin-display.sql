-- 管理画面で買い取り申請が表示されない問題を調査

-- ============================================
-- STEP 1: 買い取り申請データの確認
-- ============================================

SELECT '=== 買い取り申請データ ===' as section;

SELECT
    id,
    user_id,
    email,
    request_date,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    total_buyback_amount,
    status,
    created_at
FROM buyback_requests
ORDER BY created_at DESC;

-- ============================================
-- STEP 2: get_all_buyback_requests関数の確認
-- ============================================

SELECT '=== get_all_buyback_requests関数のテスト ===' as section;

-- 関数の定義確認
SELECT
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'get_all_buyback_requests';

-- 関数を実行してみる
SELECT * FROM get_all_buyback_requests();

-- statusでフィルタ
SELECT * FROM get_all_buyback_requests('pending');
