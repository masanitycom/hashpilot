SELECT 
    id,
    user_id,
    nft_quantity,
    amount_usd,
    usdt_address_bep20,
    usdt_address_trc20,
    payment_status,
    nft_sent,
    created_at,
    confirmed_at,
    completed_at,
    admin_approved,
    admin_approved_at,
    admin_approved_by,
    payment_proof_url,
    user_notes,
    admin_notes
FROM purchases 
LIMIT 1;
