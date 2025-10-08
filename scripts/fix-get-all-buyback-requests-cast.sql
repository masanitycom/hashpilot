-- get_all_buyback_requests関数を修正（型キャスト追加）

DROP FUNCTION IF EXISTS get_all_buyback_requests(TEXT);

CREATE OR REPLACE FUNCTION get_all_buyback_requests(p_status TEXT DEFAULT NULL)
RETURNS TABLE(
    id UUID,
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    request_date TIMESTAMP WITH TIME ZONE,
    manual_nft_count INTEGER,
    auto_nft_count INTEGER,
    total_nft_count INTEGER,
    manual_buyback_amount DECIMAL(10,2),
    auto_buyback_amount DECIMAL(10,2),
    total_buyback_amount DECIMAL(10,2),
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_status IS NULL THEN
        RETURN QUERY
        SELECT
            br.id,
            br.user_id,
            u.email::TEXT,
            u.full_name::TEXT,
            br.created_at as request_date,
            br.manual_nft_count,
            br.auto_nft_count,
            br.total_nft_count,
            br.manual_buyback_amount,
            br.auto_buyback_amount,
            br.total_buyback_amount,
            br.wallet_address,
            br.wallet_type,
            br.status,
            br.processed_by,
            br.processed_at,
            br.transaction_hash,
            br.admin_notes,
            br.created_at
        FROM buyback_requests br
        LEFT JOIN users u ON br.user_id = u.user_id
        ORDER BY br.created_at DESC;
    ELSE
        RETURN QUERY
        SELECT
            br.id,
            br.user_id,
            u.email::TEXT,
            u.full_name::TEXT,
            br.created_at as request_date,
            br.manual_nft_count,
            br.auto_nft_count,
            br.total_nft_count,
            br.manual_buyback_amount,
            br.auto_buyback_amount,
            br.total_buyback_amount,
            br.wallet_address,
            br.wallet_type,
            br.status,
            br.processed_by,
            br.processed_at,
            br.transaction_hash,
            br.admin_notes,
            br.created_at
        FROM buyback_requests br
        LEFT JOIN users u ON br.user_id = u.user_id
        WHERE br.status = p_status
        ORDER BY br.created_at DESC;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_buyback_requests(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_buyback_requests(TEXT) TO anon;

-- テスト実行
SELECT
    '=== 修正後のテスト ===' as section,
    id,
    user_id,
    email,
    full_name,
    total_nft_count,
    total_buyback_amount,
    status
FROM get_all_buyback_requests();

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ get_all_buyback_requests関数を修正';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  - u.email::TEXT, u.full_name::TEXT に型キャスト';
    RAISE NOTICE '=========================================';
END $$;
