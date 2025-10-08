-- ユーザーの買い取り申請履歴を取得する関数
-- 作成日: 2025年10月8日

CREATE OR REPLACE FUNCTION get_buyback_requests(p_user_id TEXT)
RETURNS TABLE(
    id UUID,
    user_id TEXT,
    request_date DATE,
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
    transaction_hash TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        br.id,
        br.user_id,
        br.request_date,
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
        br.transaction_hash
    FROM buyback_requests br
    WHERE br.user_id = p_user_id
    ORDER BY br.request_date DESC, br.created_at DESC;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_buyback_requests(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_buyback_requests(TEXT) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ get_buyback_requests関数を作成しました';
    RAISE NOTICE '📋 この関数でユーザーの買い取り申請履歴を取得できます';
END $$;
