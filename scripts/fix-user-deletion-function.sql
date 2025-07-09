-- ユーザー削除情報取得関数の修正（曖昧な参照エラー解決）

CREATE OR REPLACE FUNCTION get_user_deletion_info(target_user_id TEXT)
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    total_purchases NUMERIC,
    purchase_count BIGINT,
    referral_count BIGINT,
    referred_by_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.email,
        COALESCE(u.total_purchases, 0) as total_purchases,
        COALESCE(purchase_stats.purchase_count, 0) as purchase_count,
        COALESCE(referral_stats.referral_count, 0) as referral_count,
        CASE WHEN u.referrer_user_id IS NOT NULL THEN 1 ELSE 0 END::BIGINT as referred_by_count
    FROM users u
    LEFT JOIN (
        SELECT 
            p.user_id,
            COUNT(*) as purchase_count
        FROM purchases p
        WHERE p.user_id = target_user_id
        GROUP BY p.user_id
    ) purchase_stats ON u.user_id = purchase_stats.user_id
    LEFT JOIN (
        SELECT 
            r.referrer_user_id,
            COUNT(*) as referral_count
        FROM users r
        WHERE r.referrer_user_id = target_user_id
        GROUP BY r.referrer_user_id
    ) referral_stats ON u.user_id = referral_stats.referrer_user_id
    WHERE u.user_id = target_user_id;
END;
$$;

-- テスト用クエリ
SELECT 'User deletion info function fixed' as status;

-- 既存ユーザーでテスト（存在する場合）
DO $$
DECLARE
    test_user_id TEXT;
BEGIN
    -- 最初のユーザーIDを取得してテスト
    SELECT u.user_id INTO test_user_id FROM users u LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing deletion info for user: %', test_user_id;
        PERFORM get_user_deletion_info(test_user_id);
        RAISE NOTICE 'Deletion info function test completed successfully';
    ELSE
        RAISE NOTICE 'No users found for testing';
    END IF;
END;
$$;
