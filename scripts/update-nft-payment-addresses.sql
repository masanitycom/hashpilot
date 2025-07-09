-- NFT支払いページで使用するアドレス取得関数

-- 1. システム設定から送金アドレスを取得する関数
CREATE OR REPLACE FUNCTION get_payment_addresses()
RETURNS TABLE (
    bep20_address TEXT,
    trc20_address TEXT,
    nft_price DECIMAL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.usdt_address_bep20,
        s.usdt_address_trc20,
        s.nft_price
    FROM system_settings s
    WHERE s.id = 1;
END;
$$;

-- 2. 関数の実行権限を設定
GRANT EXECUTE ON FUNCTION get_payment_addresses() TO authenticated;
GRANT EXECUTE ON FUNCTION get_payment_addresses() TO anon;

-- 3. テスト実行
SELECT 
    'Payment Addresses Test' as check_type,
    *
FROM get_payment_addresses();

RAISE NOTICE 'Payment addresses function created successfully!';
