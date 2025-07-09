-- システム統計関数を作成

CREATE OR REPLACE FUNCTION get_system_stats()
RETURNS TABLE(
    total_users INTEGER,
    users_with_referrer INTEGER,
    users_with_coinw INTEGER,
    success_rate INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_users,
        COUNT(u.referrer_user_id)::INTEGER as users_with_referrer,
        COUNT(u.coinw_uid)::INTEGER as users_with_coinw,
        COALESCE(
            ROUND(
                (COUNT(CASE WHEN u.referrer_user_id IS NOT NULL AND u.coinw_uid IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0))
            )::INTEGER, 
            0
        ) as success_rate
    FROM public.users u;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 権限設定
GRANT EXECUTE ON FUNCTION get_system_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_system_stats() TO anon;

SELECT 'System stats function created successfully' as status;
