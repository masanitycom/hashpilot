-- UUID比較エラーを修正するための関数とビューの更新

-- get_user_stats関数を修正
CREATE OR REPLACE FUNCTION get_user_stats(input_user_id TEXT)
RETURNS TABLE(
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    coinw_uid TEXT,
    total_purchases NUMERIC,
    nft_count INTEGER,
    total_referrals INTEGER,
    total_referral_earnings NUMERIC,
    reward_address_bep20 TEXT,
    nft_receive_address TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id::TEXT,
        u.email::TEXT,
        u.full_name::TEXT,
        u.coinw_uid::TEXT,
        COALESCE(u.total_purchases, 0)::NUMERIC,
        FLOOR(COALESCE(u.total_purchases, 0) / 1000)::INTEGER as nft_count,
        (
            SELECT COUNT(*)::INTEGER
            FROM users r 
            WHERE r.referrer_user_id::TEXT = u.user_id::TEXT
        ),
        COALESCE(u.total_referral_earnings, 0)::NUMERIC,
        u.reward_address_bep20::TEXT,
        u.nft_receive_address::TEXT
    FROM users u
    WHERE u.id::TEXT = input_user_id::TEXT
    OR u.user_id::TEXT = input_user_id::TEXT;
END;
$$;

-- 既存の紹介ツリー関数を削除して再作成
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

CREATE OR REPLACE FUNCTION get_referral_tree(target_user_id TEXT)
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    personal_investment DECIMAL,
    level_num INTEGER,
    referrer_id TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- レベル1: 直接紹介者
        SELECT 
            u.user_id::TEXT,
            u.email::TEXT,
            FLOOR(u.total_purchases / 1000) * 1000 as personal_investment,
            1 as level_num,
            u.referrer_user_id::TEXT as referrer_id
        FROM users u 
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- レベル2以降: 間接紹介者
        SELECT 
            u.user_id::TEXT,
            u.email::TEXT,
            FLOOR(u.total_purchases / 1000) * 1000 as personal_investment,
            rt.level_num + 1,
            u.referrer_user_id::TEXT as referrer_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 10 -- 無限ループ防止
    )
    SELECT * FROM referral_tree ORDER BY level_num, personal_investment DESC;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 管理者用のビューも更新
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.coinw_uid,
    p.amount,
    p.transaction_id,
    p.status,
    p.created_at,
    u.referrer_user_id,
    ref.email as referrer_email
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
LEFT JOIN users ref ON u.referrer_user_id = ref.user_id
ORDER BY p.created_at DESC;

-- ビューの権限設定
GRANT SELECT ON admin_purchases_view TO authenticated;

-- テスト実行
SELECT 'Testing get_user_stats function:' as info;
SELECT * FROM get_user_stats('7a9637') LIMIT 1;

SELECT 'Testing get_referral_tree function:' as info;
SELECT level_num, user_id, email, personal_investment 
FROM get_referral_tree('7a9637') 
LIMIT 5;
