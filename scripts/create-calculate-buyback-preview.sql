-- 買い取り額を事前に計算する関数（申請前のプレビュー用）

CREATE OR REPLACE FUNCTION calculate_buyback_preview(
    p_user_id TEXT,
    p_manual_nft_count INTEGER,
    p_auto_nft_count INTEGER
)
RETURNS TABLE(
    manual_buyback_amount DECIMAL(10,2),
    auto_buyback_amount DECIMAL(10,2),
    total_buyback_amount DECIMAL(10,2),
    nft_count_manual INTEGER,
    nft_count_auto INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_manual_buyback DECIMAL(10,2) := 0;
    v_auto_buyback DECIMAL(10,2) := 0;
    v_nft_record RECORD;
    v_nft_buyback DECIMAL(10,2);
    v_count_manual INTEGER := 0;
    v_count_auto INTEGER := 0;
BEGIN
    -- 手動NFTの買い取り金額計算（古い順に選択）
    FOR v_nft_record IN
        SELECT id, nft_sequence
        FROM nft_master
        WHERE user_id = p_user_id
          AND nft_type = 'manual'
          AND buyback_date IS NULL
        ORDER BY nft_sequence ASC
        LIMIT p_manual_nft_count
    LOOP
        v_nft_buyback := calculate_nft_buyback_amount(v_nft_record.id);
        v_manual_buyback := v_manual_buyback + v_nft_buyback;
        v_count_manual := v_count_manual + 1;
    END LOOP;

    -- 自動NFTの買い取り金額計算（古い順に選択）
    FOR v_nft_record IN
        SELECT id, nft_sequence
        FROM nft_master
        WHERE user_id = p_user_id
          AND nft_type = 'auto'
          AND buyback_date IS NULL
        ORDER BY nft_sequence ASC
        LIMIT p_auto_nft_count
    LOOP
        v_nft_buyback := calculate_nft_buyback_amount(v_nft_record.id);
        v_auto_buyback := v_auto_buyback + v_nft_buyback;
        v_count_auto := v_count_auto + 1;
    END LOOP;

    RETURN QUERY SELECT
        v_manual_buyback,
        v_auto_buyback,
        v_manual_buyback + v_auto_buyback,
        v_count_manual,
        v_count_auto;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION calculate_buyback_preview(TEXT, INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION calculate_buyback_preview(TEXT, INTEGER, INTEGER) TO authenticated;

-- テスト: 7E0A1Eの2枚の自動NFT
SELECT '=== 7E0A1Eの自動NFT 2枚の買い取り額プレビュー ===' as section;

SELECT * FROM calculate_buyback_preview('7E0A1E', 0, 2);
