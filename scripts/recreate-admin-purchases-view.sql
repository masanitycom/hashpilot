-- purchasesテーブルの実際の構造に基づいてビューを再作成

-- 1. admin_purchases_viewを正しい列名で再作成
CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.coinw_uid,
    p.nft_quantity,
    p.amount_usd,
    p.usdt_address_bep20,
    p.usdt_address_trc20,
    p.payment_status,
    p.nft_sent,
    p.created_at,
    p.confirmed_at,
    p.completed_at,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes,
    CASE 
        WHEN p.payment_status = 'approved' THEN '✅ 承認済み'
        WHEN p.payment_status = 'pending' THEN '⏳ 保留中'
        WHEN p.payment_status = 'rejected' THEN '❌ 拒否'
        ELSE p.payment_status
    END as status_display,
    CASE 
        WHEN p.nft_sent = true THEN '✅ 送信済み'
        ELSE '⏳ 未送信'
    END as nft_status_display
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- 2. ビューが正常に作成されたか確認
SELECT 
    'view_recreation_check' as check_type,
    COUNT(*) as total_records
FROM admin_purchases_view;

-- 3. ビューのサンプルデータを確認
SELECT 
    'view_sample_data' as check_type,
    id,
    user_id,
    email,
    coinw_uid,
    nft_quantity,
    amount_usd,
    status_display,
    nft_status_display
FROM admin_purchases_view
LIMIT 3;

SELECT 'admin_purchases_view_recreated' as status, NOW() as timestamp;
