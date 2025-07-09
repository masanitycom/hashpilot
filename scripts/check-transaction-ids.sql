-- 既存のトランザクションIDの状況を確認
SELECT 
    user_id,
    email,
    referrer_user_id,
    referrer_email,
    coinw_uid,
    amount_usd,
    payment_status,
    payment_proof_url as transaction_id,
    admin_approved,
    created_at
FROM admin_purchases_view
WHERE created_at >= '2025-07-04'
ORDER BY created_at DESC
LIMIT 10;

-- トランザクションIDの統計
SELECT 
    payment_status,
    COUNT(*) as count,
    COUNT(payment_proof_url) as with_transaction_id,
    COUNT(*) - COUNT(payment_proof_url) as without_transaction_id
FROM purchases
GROUP BY payment_status
ORDER BY payment_status;
