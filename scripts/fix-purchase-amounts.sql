-- Fix purchase amounts to be in $1000 increments
UPDATE purchases 
SET 
  amount_usd = 1000,
  investment_amount = 1000,
  fee_amount = 100
WHERE amount_usd = 1100;

-- Update user total purchases to reflect $1000 per NFT
UPDATE users 
SET total_purchases = (
  SELECT COALESCE(SUM(investment_amount), 0)
  FROM purchases 
  WHERE purchases.user_id = users.id 
  AND admin_approved = true
);

-- Ensure referral tree function works properly
CREATE OR REPLACE FUNCTION get_referral_tree(root_user_id TEXT)
RETURNS TABLE(
  user_id TEXT,
  email TEXT,
  full_name TEXT,
  coinw_uid TEXT,
  level_num INTEGER,
  path TEXT,
  referrer_id TEXT,
  total_investment DECIMAL,
  direct_referrals INTEGER,
  total_referrals INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    -- Level 1: Direct referrals
    SELECT 
      u.user_id,
      u.email,
      u.full_name,
      u.coinw_uid,
      1 as level_num,
      ROW_NUMBER() OVER (ORDER BY u.created_at)::TEXT as path,
      u.referrer_user_id as referrer_id,
      COALESCE(u.total_purchases, 1000)::DECIMAL as total_investment,
      (SELECT COUNT(*)::INTEGER FROM users sub WHERE sub.referrer_user_id = u.user_id) as direct_referrals,
      0 as total_referrals,
      u.created_at
    FROM users u
    WHERE u.referrer_user_id = root_user_id
    
    UNION ALL
    
    -- Recursive: Next levels
    SELECT 
      u.user_id,
      u.email,
      u.full_name,
      u.coinw_uid,
      rt.level_num + 1,
      rt.path || '.' || ROW_NUMBER() OVER (PARTITION BY rt.user_id ORDER BY u.created_at)::TEXT,
      u.referrer_user_id,
      COALESCE(u.total_purchases, 1000)::DECIMAL,
      (SELECT COUNT(*)::INTEGER FROM users sub WHERE sub.referrer_user_id = u.user_id) as direct_referrals,
      0,
      u.created_at
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level_num < 10 -- Limit depth to prevent infinite recursion
  )
  SELECT * FROM referral_tree
  ORDER BY level_num, path;
END;
$$;

-- Grant proper permissions
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- Test the function
SELECT * FROM get_referral_tree('7a9637') LIMIT 5;
