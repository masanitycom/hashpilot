-- Create function to get user monthly summary
CREATE OR REPLACE FUNCTION get_user_monthly_summary(user_id_param UUID)
RETURNS TABLE (
    id text,
    year_month text,
    affiliate_rewards numeric,
    daily_profit_total numeric,
    total_rewards numeric,
    payment_status text,
    payment_date timestamp with time zone,
    created_at timestamp with time zone
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(umr.id::text, 'generated-' || to_char(date_trunc('month', udp.profit_date), 'YYYY-MM')) as id,
        to_char(date_trunc('month', COALESCE(umr.reward_month, udp.profit_date)), 'YYYY-MM') as year_month,
        COALESCE(umr.affiliate_rewards, SUM(udp.affiliate_rewards)) as affiliate_rewards,
        COALESCE(umr.daily_profit_total, SUM(udp.daily_profit)) as daily_profit_total,
        COALESCE(umr.total_amount, SUM(udp.affiliate_rewards + udp.daily_profit)) as total_rewards,
        COALESCE(umr.payment_status, 'pending') as payment_status,
        umr.payment_date,
        COALESCE(umr.created_at, MAX(udp.created_at)) as created_at
    FROM user_daily_profit udp
    FULL OUTER JOIN user_monthly_rewards umr 
        ON umr.user_id = udp.user_id 
        AND to_char(umr.reward_month, 'YYYY-MM') = to_char(udp.profit_date, 'YYYY-MM')
    WHERE udp.user_id = user_id_param OR umr.user_id = user_id_param
    GROUP BY 
        umr.id, 
        umr.reward_month, 
        umr.affiliate_rewards, 
        umr.daily_profit_total, 
        umr.total_amount, 
        umr.payment_status, 
        umr.payment_date, 
        umr.created_at,
        date_trunc('month', udp.profit_date)
    ORDER BY year_month DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_monthly_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_monthly_summary(UUID) TO anon;
