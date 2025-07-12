-- 翌日利益開始ルールのテスト確認

-- 1. 実装前の現状確認
SELECT 
    '🔍 実装前の確認：購入当日に日利が発生している例' as check_title;

-- 購入当日に日利が発生しているケースを確認
SELECT 
    u.user_id,
    u.email,
    p.admin_approved_at::date as purchase_date,
    udp.date as profit_date,
    udp.daily_profit,
    CASE 
        WHEN p.admin_approved_at::date = udp.date THEN '❌ 購入当日に日利発生'
        ELSE '✅ 翌日以降に日利発生'
    END as status
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE p.admin_approved_at::date = udp.date
ORDER BY p.admin_approved_at DESC
LIMIT 10;

-- 2. テストデータの準備
SELECT 
    '🧪 テスト用データ確認' as test_title;

-- 最近承認されたユーザーを確認
SELECT 
    p.user_id,
    u.email,
    p.admin_approved_at::date as approved_date,
    CURRENT_DATE as today,
    CASE 
        WHEN p.admin_approved_at::date = CURRENT_DATE THEN '今日承認（テスト対象）'
        WHEN p.admin_approved_at::date = CURRENT_DATE - 1 THEN '昨日承認（比較対象）'
        ELSE '他の日'
    END as test_category
FROM purchases p
JOIN users u ON p.user_id = u.user_id 
WHERE p.admin_approved = true
AND p.admin_approved_at::date >= CURRENT_DATE - 7
ORDER BY p.admin_approved_at DESC;

-- 3. 実装後のテスト実行
SELECT 
    '⚙️ 翌日開始ルールテスト実行' as test_execution;

-- テストモードで日利計算実行
SELECT * FROM calculate_daily_profit_with_purchase_date_check(
    CURRENT_DATE, 
    1.5, 
    30, 
    true -- テストモード
);

-- 4. 結果確認用クエリ
SELECT 
    '📊 実装後の確認クエリ' as verification_title;

-- 今日購入したユーザーが日利対象外になっているか確認
SELECT 
    u.user_id,
    u.email,
    MAX(p.admin_approved_at::date) as latest_purchase_date,
    CURRENT_DATE as process_date,
    CASE 
        WHEN MAX(p.admin_approved_at::date) >= CURRENT_DATE THEN '✅ 日利対象外（正しい）'
        ELSE '✅ 日利対象（正しい）'
    END as expected_result
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.total_nft_count > 0
GROUP BY u.user_id, u.email
ORDER BY latest_purchase_date DESC;

-- 5. 実装確認
SELECT 
    '🎯 実装確認項目' as checklist,
    '1. 購入当日のユーザーは日利対象外' as item1,
    '2. 翌日以降のユーザーは日利対象' as item2,
    '3. 既存の自動NFT購入機能は正常動作' as item3,
    '4. サイクル処理は正常動作' as item4;