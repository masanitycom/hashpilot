-- ========================================
-- 紹介ツリーの総売上を取得する関数（NFT数×$1,000で計算）
-- ========================================

CREATE OR REPLACE FUNCTION get_referral_tree_revenue(p_user_id TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_revenue NUMERIC := 0;
BEGIN
    -- 再帰クエリで紹介ツリー全体のNFT数を計算し、$1,000を掛ける
    WITH RECURSIVE referral_tree AS (
        -- ルートユーザー
        SELECT user_id, total_purchases
        FROM users
        WHERE user_id = p_user_id

        UNION ALL

        -- 子孫ユーザー（最大500レベル）
        SELECT u.user_id, u.total_purchases
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    )
    SELECT COALESCE(SUM(FLOOR(total_purchases / 1100) * 1000), 0)
    INTO v_total_revenue
    FROM referral_tree;

    RETURN v_total_revenue;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_referral_tree_revenue(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree_revenue(TEXT) TO anon;

-- テスト
SELECT get_referral_tree_revenue('7A9637') as tree_revenue;

SELECT '✅ get_referral_tree_revenue関数を作成しました' as status;
