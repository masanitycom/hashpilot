-- ユーザー2BF53BのNFTデータを確認

-- 1. affiliate_cycleテーブルのデータを確認
SELECT 
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    last_updated
FROM affiliate_cycle
WHERE user_id = '2BF53B';

-- 2. NFTトランザクション履歴があるか確認（テーブルが存在する場合）
-- SELECT * FROM nft_transactions WHERE user_id = '2BF53B' ORDER BY created_at DESC LIMIT 10;

-- 3. 自動購入履歴を確認（テーブルが存在する場合）
-- SELECT * FROM auto_purchase_history WHERE user_id = '2BF53B' ORDER BY created_at DESC;

-- 4. 全ユーザーのNFT保有状況を確認（上位10名）
SELECT 
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt
FROM affiliate_cycle
WHERE total_nft_count > 0
ORDER BY total_nft_count DESC
LIMIT 10;

-- 5. テスト用：NFT数を2に更新する関数
CREATE OR REPLACE FUNCTION test_update_nft_count(p_user_id TEXT, p_manual_count INTEGER, p_auto_count INTEGER)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- affiliate_cycleのNFT数を更新
    UPDATE affiliate_cycle
    SET 
        manual_nft_count = p_manual_count,
        auto_nft_count = p_auto_count,
        total_nft_count = p_manual_count + p_auto_count,
        last_updated = NOW()
    WHERE user_id = p_user_id;
    
    IF FOUND THEN
        RETURN QUERY
        SELECT 
            TRUE,
            format('ユーザー %s のNFT数を更新しました: 手動=%s, 自動=%s, 合計=%s', 
                   p_user_id, p_manual_count, p_auto_count, p_manual_count + p_auto_count)::TEXT;
    ELSE
        RETURN QUERY
        SELECT 
            FALSE,
            format('ユーザー %s が見つかりません', p_user_id)::TEXT;
    END IF;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION test_update_nft_count(TEXT, INTEGER, INTEGER) TO authenticated;

-- テスト実行例：
-- ユーザー2BF53BのNFT数を手動1、自動1の合計2に設定
-- SELECT * FROM test_update_nft_count('2BF53B', 1, 1);