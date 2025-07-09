-- デフォルトの支払いアドレスを設定

-- 1. システム設定にデフォルトアドレスを設定
UPDATE system_settings 
SET 
    usdt_address_bep20 = '0x1234567890123456789012345678901234567890',
    usdt_address_trc20 = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    updated_at = NOW()
WHERE id = 1;

-- 2. 設定が存在しない場合は挿入
INSERT INTO system_settings (
    id, 
    usdt_address_bep20, 
    usdt_address_trc20, 
    nft_price, 
    maintenance_mode
)
SELECT 
    1,
    '0x1234567890123456789012345678901234567890',
    'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    1100.00,
    FALSE
WHERE NOT EXISTS (SELECT 1 FROM system_settings WHERE id = 1);

-- 3. 確認
SELECT 
    'Payment Addresses After Update' as check_type,
    *
FROM get_payment_addresses();
